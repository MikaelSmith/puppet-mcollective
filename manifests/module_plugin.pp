define mcollective::module_plugin (
  String $config_name,
  Array[String] $client_files = [],
  Array[String] $client_directories = [],
  Array[String] $server_files = [],
  Array[String] $server_directories = [],
  Array[String] $common_files = [],
  Array[String] $common_directories = [],
  Boolean $manage_gem_dependencies = true,
  Hash $gem_dependencies = {},
  Boolean $manage_package_dependencies = true,
  Hash $package_dependencies = {},
  Boolean $manage_class_dependencies = true,
  Array[String] $class_dependencies = [],
  Mcollective::Policy_action $policy_default = $mcollective::policy_default,
  Array[Mcollective::Policy] $policies = [],
  Array[Mcollective::Policy] $site_policies = $mcollective::site_policies,
  Hash $config = {},
  Hash $client_config = {},
  Hash $server_config = {},
  Boolean $client = $mcollective::client,
  Boolean $server = $mcollective::server,
  String $libdir = $mcollective::libdir,
  String $configdir = $mcollective::configdir,
  String $owner = $mcollective::plugin_owner,
  String $group = $mcollective::plugin_group,
  String $mode = $mcollective::plugin_mode,
  Enum["present", "absent"] $ensure = "present"
) {
  if ($server and $client) {
    $merged_conf = $config.deep_merge($client_config).deep_merge($server_config)
    $merged_files = $common_files + $server_files + $client_files
    $merged_directories = $common_directories + $server_directories + $client_directories

  } elsif($server) {
    $merged_conf = $config.deep_merge($server_config)
    $merged_files = $common_files + $server_files
    $merged_directories = $common_directories + $server_directories

  } elsif($client) {
    $merged_conf = $config.deep_merge($client_config)
    $merged_files = $common_files + $client_files
    $merged_directories = $common_directories + $client_directories
  }

  if $manage_class_dependencies and !$class_dependencies.empty {
    require $class_dependencies
  }

  if $manage_gem_dependencies {
    $gem_dependencies.each |$gem, $version| {
      package{$gem:
        ensure   => $version,
        provider => "puppet_gem"
      }
    }
  }

  if $manage_package_dependencies {
    $package_dependencies.each |$pkg, $version| {
      package{$pkg:
        ensure   => $version
      }
    }
  }

  if $name =~ /^mcollective_agent_(.+)/ {
    $agent_name = $1

    $policy_content = epp("mcollective/policy_file.epp", {
      "module"         => $name,
      "policy_default" => $policy_default,
      "policies"       => $policies,
      "site_policies"  => $site_policies
    })

    file{"${configdir}/policies/${agent_name}.policy":
      owner      => $owner,
      group      => $group,
      mode       => $mode,
      content    => $policy_content
    }
  }

  unless $merged_conf.empty {
    $merged_conf.each |$item, $value| {
      ini_setting{"${name}-${config_name}-${item}":
        ensure  => $ensure,
        path    => "${configdir}/plugin.d/${config_name}.conf",
        setting => $item,
        value   => $value
      }
    }
  }

  $merged_directories.each |$file| {
    unless defined(File["${libdir}/${file}"]) {
      file{"${libdir}/${file}":
        owner  => $owner,
        group  => $group,
        mode   => $mode,
        ensure => $ensure ? {"present" => "directory", "absent" => "absent"}
      }
    }
  }

  $merged_files.each |$file| {
    file{"${libdir}/${file}":
      source => "puppet:///modules/${caller_module_name}/mcollective/${file}",
      owner  => $owner,
      group  => $group,
      mode   => $mode,
      ensure => $ensure
    }
  }

  Mcollective::Module_plugin[$name] ~> Class["mcollective::service"]
}
