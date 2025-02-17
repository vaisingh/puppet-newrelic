# == Class: newrelic::server::linux
#
# This class installs and configures NewRelic server monitoring.
#
# === Parameters
#
# [*newrelic_service_enable*]
#   Specify the service startup state. Defaults to true. Possible value is false.
#
# [*newrelic_service_ensure*]
#   Specify the service running state. Defaults to 'running'. Possible value is 'stopped'.
#
# [*newrelic_package_ensure*]
#   Specify the package update state. Defaults to 'present'. Possible value is 'latest'.
#
# [*newrelic_license_key*]
#   Specify your Newrelic License Key.
#
# === Variables
#
# === Examples
#
#  class {'newrelic::server::linux':
#      newrelic_license_key    => 'your license key here',
#      newrelic_package_ensure => 'latest',
#      newrelic_service_ensure => 'running',
#  }
#
# === Authors
#
# Felipe Salum <fsalum@gmail.com>
#
# === Copyright
#
# Copyright 2012 Felipe Salum, unless otherwise noted.
#
class newrelic::server::linux (
  $newrelic_license_key                  = undef,
  $newrelic_package_ensure               = 'present',
  $newrelic_package_name                 = $::newrelic::params::newrelic_package_name,
  $newrelic_service_enable               = true,
  $newrelic_service_ensure               = 'running',
  $newrelic_service_name                 = $::newrelic::params::newrelic_service_name,
  $newrelic_nrsysmond_cgroup_root        = undef,
  $newrelic_nrsysmond_cgroup_style       = undef,
  $newrelic_nrsysmond_collector_host     = undef,
  $newrelic_nrsysmond_disable_docker     = undef,
  $newrelic_nrsysmond_disable_nfs        = undef,
  $newrelic_nrsysmond_docker             = false,
  $newrelic_nrsysmond_docker_cacert      = undef,
  $newrelic_nrsysmond_docker_cert        = undef,
  $newrelic_nrsysmond_docker_cert_path   = undef,
  $newrelic_nrsysmond_docker_connection  = undef,
  $newrelic_nrsysmond_docker_key         = undef,
  $newrelic_nrsysmond_host_root          = undef,
  $newrelic_nrsysmond_hostname           = undef,
  $newrelic_nrsysmond_ignore_reclaimable = undef,
  $newrelic_nrsysmond_labels             = undef,
  $newrelic_nrsysmond_logfile            = undef,
  $newrelic_nrsysmond_loglevel           = undef,
  $newrelic_nrsysmond_logrotate          = false,
  $newrelic_nrsysmond_manage_repo        = true,
  $newrelic_nrsysmond_pidfile            = undef,
  $newrelic_nrsysmond_proxy              = undef,
  $newrelic_nrsysmond_ssl                = undef,
  $newrelic_nrsysmond_ssl_ca_bundle      = undef,
  $newrelic_nrsysmond_ssl_ca_path        = undef,
  $newrelic_nrsysmond_timeout            = undef,
) inherits ::newrelic {

  if ! $newrelic_license_key {
    fail('You must specify a valid License Key.')
  }

  if $newrelic_nrsysmond_manage_repo {
    case $::osfamily {
      'RedHat': {
        package { 'newrelic-repo-5-3.noarch':
          ensure   => present,
          source   => 'http://yum.newrelic.com/pub/newrelic/el5/x86_64/newrelic-repo-5-3.noarch.rpm',
          provider => rpm,
        }
      }
      'Debian': {
        apt::source { 'newrelic':
          location => 'http://apt.newrelic.com/debian/',
          repos    => 'non-free',
          key      => {
            id  => 'B60A3EC9BC013B9C23790EC8B31B29E5548C16BF',
            key => 'https://download.newrelic.com/548C16BF.gpg',
          },
          include  => {
            src => false,
          },
          release  => 'newrelic',
        }
      }
      default: {
        fail("Unsupported osfamily: ${::osfamily} operatingsystem: ${::operatingsystem}")
      }
    }
  }
  package { $newrelic_package_name:
    ensure  => $newrelic_package_ensure,
    notify  => Service[$newrelic_service_name],
    require => Class['newrelic::params'],
  }

  if ! $newrelic_nrsysmond_logfile {
    $logdir = '/var/log/newrelic'
  } else {
    $logdir = dirname($newrelic_nrsysmond_logfile)
  }

  file { $logdir:
    ensure  => directory,
    owner   => 'newrelic',
    group   => 'newrelic',
    require => Package[$newrelic_package_name],
    before  => Service[$newrelic_service_name],
  }

  file { '/etc/newrelic/nrsysmond.cfg':
    ensure  => present,
    path    => '/etc/newrelic/nrsysmond.cfg',
    content => template('newrelic/nrsysmond.cfg.erb'),
    require => Package[$newrelic_package_name],
    before  => Service[$newrelic_service_name],
    notify  => Service[$newrelic_service_name],
  }

  service { $newrelic_service_name:
    ensure     => $newrelic_service_ensure,
    enable     => $newrelic_service_enable,
    hasrestart => true,
    hasstatus  => true,
    require    => Exec[$newrelic_license_key],
  }

  exec { $newrelic_license_key:
    path    => '/bin:/usr/bin',
    command => "/usr/sbin/nrsysmond-config --set license_key=${newrelic_license_key}",
    user    => 'root',
    group   => 'root',
    unless  => "cat /etc/newrelic/nrsysmond.cfg | grep ${newrelic_license_key}",
    require => Package[$newrelic_package_name],
    notify  => Service[$newrelic_service_name],
  }

  if $newrelic_nrsysmond_docker {
    # Newrelic must belong to the Docker group to fetch metrics.
    exec { 'newrelic-should-be-in-docker-group':
      command => '/usr/sbin/usermod -aG docker newrelic',
      unless  => "/bin/cat /etc/group | grep '^docker:' | grep -qw newrelic",
      notify  => Service[$newrelic_service_name]
    }
  }

}
