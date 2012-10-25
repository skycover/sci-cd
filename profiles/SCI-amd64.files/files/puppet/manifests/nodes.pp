node 'default' {
	include common_profile, sources_list_local
	class { timezone: zone => "Europe/Moscow", }
	class { locale: def_locale => "en_US.UTF-8", }
}

node 'sci' {
	include common_profile, bind9_sci, approx_local, sources_list_local
	class { timezone: zone => "Europe/Moscow", }
	class { locale: def_locale => "en_US.UTF-8", }
}
