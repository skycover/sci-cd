node 'default' {
	include common_profile, sources_list_local
	class { timezone: zone => "Europe/Moscow", }
	class { locale: def_locale => "ru_RU.UTF-8", }
}

node 'sci' {
	include common_profile, bind9_sci, approx_local, sources_list_local
	class { timezone: zone => "Europe/Moscow", }
	class { locale: def_locale => "ru_RU.UTF-8", }
	class { dhcpd: enabled => "no", }
}
