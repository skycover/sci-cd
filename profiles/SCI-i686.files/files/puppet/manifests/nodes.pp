node 'default' {
	Package { allowcdrom => true }
	include common_profile
}

node 'sci' {
	Package { allowcdrom => true }
	include common_profile, bind9_chroot, approx
}
