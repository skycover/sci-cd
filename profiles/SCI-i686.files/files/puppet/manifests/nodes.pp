node 'default' {
	include common_profile, apt_local_repos
}

node 'sci' {
	include common_profile, bind9_sci, approx_local, apt_local_repos
}
