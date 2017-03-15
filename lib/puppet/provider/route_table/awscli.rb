#  Copyright (C) 2017 IntechnologyWIFI / Michael Shaw
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'json'
require 'puppet_x/intechwifi/constants'
require 'puppet_x/intechwifi/logical'
require 'puppet_x/intechwifi/awscmds'
require 'puppet_x/intechwifi/exceptions'

Puppet::Type.type(:route_table).provide(:awscli) do
  commands :awscli => "aws"

  def create
    begin
      vpcid = PuppetX::IntechWIFI::AwsCmds.find_id_by_name(resource[:region], "vpc", resource[:vpc]) { | *arg | awscli(*arg) }

    rescue PuppetX::IntechWIFI::Exceptions::NotFoundError => e
      fail("We cannot create this route table, unless the vpc=>#{resource[:vpc]} already exists.")
    end

    args = [
        'ec2', 'create-route-table',
        '--region', @resource[:region],
        '--vpc-id', vpcid,
    ]

    rt = JSON.parse(awscli(args))["RouteTable"]
    @property_hash[:rtid] = rt["RouteTableId"]

    awscli('ec2', 'create-tags', '--region', resource[:region], '--resources', @property_hash[:rtid], '--tags', "Key=Name,Value=#{resource[:name]}", "Key=Environment,Value=#{resource[:environment]}")

  end

  def destroy
    args = [
        'ec2', 'delete-route-table',
        '--region', @property_hash[:region],
        '--route-table-id', @property_hash[:rtid],
    ]

    awscli(args)

  end

  def exists?
    search_result = PuppetX::IntechWIFI::AwsCmds.find_tag([@resource[:region]], 'route-table', "Name", "value" ,resource[:name]) { | *arg |  awscli(*arg) }
    @property_hash[:ensure] = :present
    @property_hash[:rtid] = search_result[:tag]["ResourceId"]
    @property_hash[:region] = search_result[:region]
    @property_hash[:name] = resource[:name]

    details_args = [
        'ec2', 'describe-route-tables',
        '--region', @property_hash[:region],
        '--route-table-ids', @property_hash[:rtid]
    ]

    rts = JSON.parse(awscli(details_args))["RouteTables"]

    raise PuppetX::IntechWIFI::Exceptions::NotFoundError, resource[:name] if rts.length == 0
    raise PuppetX::IntechWIFI::Exceptions::MultipleMatchesError, resource[:name] if rts.length > 1

    rt = rts[0]

    @property_hash[:vpc]= PuppetX::IntechWIFI::AwsCmds.find_name_or_id_by_id(@property_hash[:region], "vpc", rt["VpcId"]){ | *arg | awscli(*arg) }
    @property_hash[:vpc_default] = rt["Associations"].select{|x| x["Main"] == true}.map{|x| x["Main"]}.reduce(PuppetX::IntechWIFI::Logical.logical(false)){ |memo, value| PuppetX::IntechWIFI::Logical.logical_true(memo) ? memo : PuppetX::IntechWIFI::Logical.logical(value)}
    @property_hash[:subnets] = rt["Associations"].select{|x| !x["SubnetId"].nil?}.map do |x|
      PuppetX::IntechWIFI::AwsCmds.find_name_or_id_by_id(@property_hash[:region], "subnet", x["SubnetId"]){ | *arg | awscli(*arg) }
    end
    @property_hash[:environment] = PuppetX::IntechWIFI::AwsCmds.find_tag_from_list(rt["Tags"], "Environment")

    true

  rescue PuppetX::IntechWIFI::Exceptions::NotFoundError => e
    debug(e)
    false

  rescue PuppetX::IntechWIFI::Exceptions::MultipleMatchesError => e
    fail(e)
    false
  end

  def flush
    if @property_flush
    end
  end

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  mk_resource_methods


end