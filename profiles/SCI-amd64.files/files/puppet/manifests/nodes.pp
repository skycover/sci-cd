node 'default' {
	class { sources_list_local: stage => pre0, }
	class { common_profile: stage => pre1, }
	class { timezone: zone => "Europe/Moscow", stage => main, }
	class { locale: def_locale => "ru_RU.UTF-8", stage => main, }
}

node 'sci' {
	class { approx_local: stage => pre0, }
	class { sources_list_local: stage => pre0, }
	class { common_profile: stage => pre1, }
	class { bind9_sci: stage => main, }
	class { timezone: zone => "Europe/Moscow", stage => main, }
	class { locale: def_locale => "ru_RU.UTF-8", stage => main, }
	class { dhcpd: enabled => no, stage => post1, }
}
