node 'default' {
	include common_profile, sources_list_local
}

node 'sci' {
	include common_profile, bind9_sci, approx_local, sources_list_local
}
