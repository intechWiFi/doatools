define doatools::network (
  $vpc=$name,
  $l_vpc=$vpc,
  $ensure=lookup('network::ensure', Data, 'first', present),
  $vpc_cidr=lookup('network::vpc_cidr', Data, 'first', '192.168.0.0/24'),
  $region=lookup('network::region', Data, 'first', 'us-east-1'),
  $tags=lookup('network::tags', Data, 'first', {}),
  $availability = lookup('network::availability', Data, 'first', [ 'a', 'b', 'c']),
  $internet_access = lookup('network::internet_access', Data, 'first', true),
  $routes = lookup('network::routes', Data, 'first', []),
  $default_access = lookup('network::default_access', Data, 'first', {
    ingress => [ "all||sg|${name}" ],
    egress  => [ "all||sg|${name}" ],
  }),
  $zones = lookup('network::zones', Data, 'first', [{
    label     => '%{vpc}%{az}',
    cidr      => $vpc_cidr,
    public_ip => true,
  }]),
){
  define_network_resources($ensure,
    {  name => $vpc, cidr => $vpc_cidr, region=> $region, tags => $tags, availability => $availability, routes => $routes },
    $zones,
    $default_access
  ).each |$r| {
    $rt = $r['resource_type']
    $rts = $r['resources'].keys
    info("declaring resources: ${rt} ${rts}")
    create_resources($r['resource_type'], $r['resources'], {})
  }
}