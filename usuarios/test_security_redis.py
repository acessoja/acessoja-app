"""Shared security counters across actual processes; isolated Redis DB only."""
import multiprocessing
import os
from types import SimpleNamespace
from unittest.mock import patch
import uuid

import pytest

URL = os.environ.get('SECURITY_REDIS_TEST_URL')
pytestmark = pytest.mark.skipif(not URL, reason='Requires isolated real Redis; geographic-coordination CI provided.')


def attempt(url, prefix, index, start, output):
    import django
    django.setup()
    from django.test import override_settings
    from usuarios.security_throttles import SecurityThrottle
    config = {'default': {'BACKEND': 'django.core.cache.backends.redis.RedisCache',
                          'LOCATION': url, 'KEY_PREFIX': prefix}}
    request = SimpleNamespace(data={'email': 'Synthetic-Private@example.test'},
                              user=SimpleNamespace(is_authenticated=False),
                              META={'REMOTE_ADDR': f'192.0.2.{index + 1}'})
    with override_settings(CACHES=config), patch('usuarios.security_throttles.time.time', return_value=1792580000):
        start.wait(15)
        output.put(SecurityThrottle().allow_request(request, SimpleNamespace(security_scope='reset_request')))


def test_real_redis_workers_share_identifier_budget_and_keys_contain_no_personal_data():
    import redis
    client = redis.Redis.from_url(URL)
    prefix = 'security-regression-' + uuid.uuid4().hex
    ctx = multiprocessing.get_context('spawn')
    start, output = ctx.Event(), ctx.Queue()
    workers = [ctx.Process(target=attempt, args=(URL, prefix, i, start, output)) for i in range(8)]
    try:
        for worker in workers:
            worker.start()
        start.set()
        outcomes = [output.get(timeout=25) for worker in workers]
        for worker in workers:
            worker.join(10)
            assert worker.exitcode == 0
        assert sum(outcomes) == 5
        keys = client.keys(prefix + '*')
        assert len(keys) == 9 and all(b'example' not in key and b'192.0.2' not in key for key in keys)
        assert max(int(client.get(key)) for key in keys) == 8
    finally:
        for worker in workers:
            if worker.is_alive():
                worker.terminate()
                worker.join(5)
        keys = client.keys(prefix + '*')
        if keys:
            client.delete(*keys)
        output.close()


def progressive_failures(url, prefix, start, output):
    import django
    django.setup()
    from django.test import override_settings
    from usuarios.security_throttles import LoginProtection
    config = {'default': {'BACKEND': 'django.core.cache.backends.redis.RedisCache',
                          'LOCATION': url, 'KEY_PREFIX': prefix}}
    with override_settings(CACHES=config):
        guard = LoginProtection(SimpleNamespace(META={'REMOTE_ADDR': '192.0.2.1'}), 'synthetic-user')
        start.wait(15)
        for _ in range(3):
            guard.result(False)
        output.put(True)


def test_real_redis_progressive_failures_are_atomic_and_reset_only_the_pair():
    import redis
    from django.test import override_settings
    from rest_framework.exceptions import Throttled
    from usuarios.security_throttles import LoginProtection
    client = redis.Redis.from_url(URL)
    prefix = 'progressive-auth-' + uuid.uuid4().hex
    config = {'default': {'BACKEND': 'django.core.cache.backends.redis.RedisCache',
                          'LOCATION': URL, 'KEY_PREFIX': prefix}}
    ctx = multiprocessing.get_context('spawn')
    start, output = ctx.Event(), ctx.Queue()
    workers = [ctx.Process(target=progressive_failures, args=(URL, prefix, start, output)) for _ in range(4)]
    try:
        for worker in workers:
            worker.start()
        start.set()
        assert all(output.get(timeout=30) for _ in workers)
        for worker in workers:
            worker.join(10)
            assert worker.exitcode == 0
        with override_settings(CACHES=config):
            from django.core.cache import cache
            guard = LoginProtection(SimpleNamespace(META={'REMOTE_ADDR': '192.0.2.1'}), 'synthetic-user')
            assert cache.get(guard.key) == 12
            with pytest.raises(Throttled) as exc:
                guard.check()
            assert 870 <= exc.value.wait <= 900
            other = LoginProtection(SimpleNamespace(META={'REMOTE_ADDR': '192.0.2.2'}), 'synthetic-user')
            other.result(False)
            guard.result(True)
            assert cache.get(guard.key) is None and cache.get(other.key) == 1
            assert all(b'synthetic-user' not in key and b'192.0.2' not in key for key in client.keys(prefix + '*'))
    finally:
        for worker in workers:
            if worker.is_alive():
                worker.terminate()
                worker.join(5)
        keys = client.keys(prefix + '*')
        if keys:
            client.delete(*keys)
        output.close()
