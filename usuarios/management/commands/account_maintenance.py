"""Protected daily retention and receipt reconciliation for the pilot worker."""
from datetime import timedelta
from pathlib import Path
import os
import time

from django.conf import settings
from django.core.management import call_command
from django.core.management.base import BaseCommand
from django.utils import timezone
from usuarios.deletion_journal import journal_identity


class Command(BaseCommand):
    help = 'Manter retenção e recibos de exclusão; usar somente no banco ativo.'

    def add_arguments(self, parser):
        parser.add_argument('--watch', action='store_true')

    def handle(self, *args, **options):
        while True:
            journal_identity(initialize=settings.APP_ENV != 'staging')
            call_command('sync_privacy_deletions', authoritative_live_database=True, stdout=self.stdout)
            call_command('prune_account_state', stdout=self.stdout)
            call_command('clearsessions', stdout=self.stdout)
            # Logrotate handles open application files; Caddy handles its own
            # rotation. Remove stale rotated archives as a second retention bound.
            log_dir = os.environ.get('SECURE_LOG_DIR')
            cutoff = (timezone.now() - timedelta(days=14)).timestamp()
            if log_dir:
                for path in Path(log_dir).glob('*.log*'):
                    if path.is_file() and not path.is_symlink() and path.stat().st_mtime < cutoff:
                        if path.name.endswith('.log'):
                            # Reset an inactive current log without unlinking an open inode.
                            with path.open('w', encoding='utf-8'):
                                pass
                        else:
                            path.unlink()
            if not options['watch']:
                return
            # Frequent receipt reconciliation; age-based maintenance is idempotent.
            time.sleep(60)
