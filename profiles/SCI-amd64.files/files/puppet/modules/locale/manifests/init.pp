class locale(def_locale="en_US.UTF-8") {
	package { locales : ensure => installed }
	
	file { "/etc/default/locale":
		owner   => root,
		group   => root,
		mode    => 644,
		content => template("locale/locale.erb"),
		require => Package["locales"],
	}
	
	file { "/etc/locale.gen":
		owner   => root,
		group   => root,
		mode    => 644,
		source  => "puppet:///modules/locale/locale.gen",
		require => Package["locales"],
	}
}

