#!/bin/sh

# In the case of UPS failure we can't rely on the cluster master availability.
# We will shutdown the ganeti daemons and next - the virtual instances,
# But we will stay with Dom0 running for the case of pending DRBD sync.
# The real power off will drop Dom0, but this is safe because of journalling fs.

# In the case the power will not off, the admin can symply run the ganeti daemons back
# And the watcher will do the rest of the job.

# In the case of the power off and then the node restart,
# it will up in the normal state without any intervention.

/etc/init.d/ganeti-watcher stop
sleep 10
/etc/init.d/ganeti stop

/etc/init.d/xendomains stop
