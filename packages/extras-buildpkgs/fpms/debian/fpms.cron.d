#
# Regular cron jobs for the fpms package
# See dh_installcron(1) and crontab(5).
#
@reboot     root    /usr/share/fpms/BakeBit/Software/Python/scripts/networkinfo/networkinfocron.sh
