$approxTemplates="/etc/puppet/modules/approx/templates"

class approx {
	package { 'approx': ensure => installed, allowcdrom => true } 
	file { "/etc/approx/approx.conf":
		owner => "root",
		group => "root",
		mode => 0644,
		content => template("/etc/puppet/modules/approx/templates/approx.conf.erb"),
		require => Package['approx'],
	}
}

class apt {
    file { "/etc/apt/sources.list":
        owner => "root", group => "root", mode => 0644,
	content => template("/etc/puppet/modules/approx/templates/sources.list.erb")
    }
    exec{'/usr/bin/apt-get update':
        refreshonly => true,
        subscribe => File['/etc/apt/sources.list']
    }
}
