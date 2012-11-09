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
		content => template("locale/locale.gen.erb"),
		require => Package["locales"],
	}

	exec { 'regenerate-locales':
		command => '/usr/sbin/locale-gen',
		subscribe => File['/etc/locale.gen'],
		require => Package["locales"],
		refreshonly => true,
	}
}

