import "lib.pp"

class common_profile {
	include root_bashrc, vim, common_packages, sysstat
	# ntp, zabbix-agent
}

class common_packages {
	package {
		[ 'less',
		  'psmisc',
		  'openssh-client',
		  'dnsutils',
		  'sudo',
		  'bash-completion',
		]:
		ensure => installed
	}
}

class root_bashrc {
	file { '/root/.bashrc':
		mode => 644, owner => root, group => root,
		source => 'puppet:///modules/common/root_bashrc'
	}
}

class sysstat {
	package { 'sysstat': ensure => installed }

	file { '/etc/default/sysstat':
		mode => 644, owner => root, group => root,
		source => 'puppet:///modules/common/sysstat_default',
		require => Package['sysstat']
	}
}

class ntp {
	package { 'ntp': ensure => installed }

	file { 'ntp.conf':
		name =>'/etc/ntp.conf',
		mode => 644, owner => root, group => root,
		content => template("/etc/puppet/modules/common/templates/ntp.conf.erb"),
		require => Package['ntp']
	}

	service { 'ntp':
		subscribe => File[ 'ntp.conf' ],
		require => [ Package['ntp'] ]
	}
}

class zabbix-agent {
	package { 'zabbix-agent': ensure => installed }

	file { 'zabbix_agentd.conf':
		name =>'/etc/zabbix/zabbix_agentd.conf',
		mode => 660, owner => zabbix, group => root,
		content => template("/etc/puppet/modules/common/templates/zabbix_agentd.conf.erb"),
		require => Package['zabbix-agent']
	}

	service { 'zabbix-agent':
		subscribe => File[ 'zabbix_agentd.conf' ],
		require => [ Package['zabbix-agent'] ]
	}
}

class vim {
	package { 'vim': ensure => installed }

	file { 'vimrc.local':
		name => '/etc/vim/vimrc.local',
		mode => 644, owner => root, group => root,
		source => 'puppet:///modules/common/vimrc.local',
		require => Package['vim']
	}

	check_alternatives { 'editor':
		linkto => '/usr/bin/vim.basic',
		package => "vim",
	}
}

class ssh_server {

	package { 'openssh-server':
		ensure => installed
	}

	file { 'sshdconfig':
		name => '/etc/ssh/sshd_config',
		owner => root,
		group => root,
		mode  => 644,
		#content => template( 'ssh/sshd_config.erb' ),
		#source => 'puppet:///modules/ssh/sshd_config',
		require => Package['openssh-server']
	}

	service { 'ssh':
		subscribe => File[ 'sshdconfig' ],
		require => [ Package['openssh-server'] ]
	}
}
