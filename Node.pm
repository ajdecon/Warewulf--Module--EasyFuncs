package Node;

use Warewulf::DataStore;
use Warewulf::Provision::Pxelinux;
use Warewulf::Provision::HostsFile;
use Warewulf::Provision::DhcpFactory;
use Warewulf::ParallelCmd;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_nodes nodes_by_cluster get_nodes set_node_properties reboot_nodes poweron_nodes poweroff_nodes power_action);

# get_all_nodes
#   Return full hash of all nodes provisioned by Warewulf.
#   Return nodeid, node name, ip/netmask of eth0,
#   cluster, hwaddr, vnfsid, bootstrapid, fileids.
sub get_all_nodes {
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node','_id',());
    my %nodes = nodes_hash($nodeSet);
    #my %nodes = nodes_hash2($nodeSet);
    return %nodes;
}

# get_nodes
#   Using a given lookup, return all nodes with that parameter.
sub get_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    #    print "array = $ident[0]\n";
    } else {
        push(@ident,$ref);
    }
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node',$lookup,@ident);
    #print "Count = " . $nodeSet->count() . "\n";
    return nodes_hash($nodeSet);
}

# nodes_by_cluster
#   Return node hash of nodes in a given cluster.
sub nodes_by_cluster {
    my $cluster = shift;
    if ($cluster eq "UNDEF") {
        $cluster = undef;
    }
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node','cluster',($cluster));
    return nodes_hash($nodeSet);
}

# set_node_properties
#   Sets node properties according to a passed hash.
#   ($lookup, \%nodehash)
sub set_node_properties {
    my $lookup = shift;
    my $p = shift;
    my %props = %{$p};

    my $db = Warewulf::DataStore->new();
    my @idlist;

    foreach my $id (keys %props) {
        push(@idlist,$id);
        my $node = ( ($db->get_objects('node','_id',($id)))->get_list() )[0];
        my @netdevs = $node->get('netdevs');
#        print "Nodeid $id found node with name " . $node->get('name') . " \n";
        foreach my $p (keys %{ $props{$id} } ) {
            print "Nodeid $id Prop $p = $props{$id}{$p} \n";
            if ($p eq 'netdevs') {
                foreach my $nd (@netdevs) {
                    if ($props{$id}{$p}{$nd->get('name')}) {
                        foreach my $ndparam ( keys %{ $props{$id}{$p}{$nd->get('name')} } ) {
#                            print "I have $ndparam of " . $nd->get('name') . " being set to " . $props{$id}{$p}{$nd->get('name')}{$ndparam} . "\n";
                            $nd->set($ndparam, $props{$id}{$p}{$nd->get('name')}{$ndparam});
                        }
                    }
                }
            } elsif ($p eq 'fileids') {
                my @fids = @{ $props{$id}{$p} };
                $node->set('fileids',@fids);
            } else {
                $node->set($p,$props{$id}{$p});
            }
        }
        $db->persist($node);
    }
    
    my $pxe = Warewulf::Provision::Pxelinux->new();
    my $dhcp = Warewulf::Provision::DhcpFactory->new();
    my $hostsfile = Warewulf::Provision::HostsFile->new();
    my $nodeSet = $db->get_objects('node','_id',@idlist);
    
    $dhcp->persist();
    $hostsfile->update_datastore();
    $pxe->update($nodeSet);

    return nodes_hash($nodeSet);
}

# poweroff_nodes
sub poweroff_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    return power_action($lookup,"power off",\@ident);
}

# poweron_nodes
sub poweron_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    return power_action($lookup,"power on",\@ident);
}

# reboot_nodes
sub reboot_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    return power_action($lookup,"power cycle",\@ident);
}

# power_action
#   ($lookup, $action, @ident)
sub power_action {
    my $lookup = shift;
    my $action = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    my %results;
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node',$lookup,@ident);
    my $cmd = Warewulf::ParallelCmd->new();
    $cmd->fanout(4);
    foreach my $o ($nodeSet->get_list()) {
        if (my $ipaddr = $o->get("ipmi_ipaddr") and my $username = $o->get("ipmi_username") and my $password = $o->get("ipmi_password")) {
            $cmd->queue("ipmitool -I lan -U $username -P $password -H $ipaddr chassis $action");
            $results{$o->get('_id')}{"status"} = "IPMI $action sent";
        } else {
            $results{$o->get('_id')}{'status'} = "error";
            $results{$o->get('_id')}{'error'} = "Node IPMI settings not complete";
        }
    }
    $cmd->run();
    return %results;
}

# nodes_hash
#   Return hash of node details from object set.
sub nodes_hash {
    my $nodeSet = shift;
    my %nodes;
    foreach my $node ($nodeSet->get_list()) {
        my $id = $node->get('_id');
        $nodes{$id}{'_id'} = $node->get('_id');
        $nodes{$id}{'name'} = $node->get('name');
        $nodes{$id}{'vnfsid'} = $node->get('vnfsid');
        $nodes{$id}{'bootstrapid'} = $node->get('bootstrapid');
        $nodes{$id}{'cluster'} = $node->get('cluster');
        $nodes{$id}{'domain'} = $node->get('domain');
        $nodes{$id}{'fqdn'} = $node->get('fqdn');
        $nodes{$id}{'kargs'} = $node->get('kargs');
        $nodes{$id}{'fileids'} = $node->get('fileids') ;

        $nodes{$id}{'filesystems'} = $node->get('filesystems');
        $nodes{$id}{'diskformat'} = $node->get('diskformat');
        $nodes{$id}{'diskpartition'} = $node->get('diskpartition');
        $nodes{$id}{'bootloader'} = $node->get('bootloader');
        $nodes{$id}{'bootlocal'} = $node->get('bootlocal');

        $nodes{$id}{'ipmi_username'} = $node->get('ipmi_username');
        $nodes{$id}{'ipmi_password'} = $node->get('ipmi_password');
        $nodes{$id}{'ipmi_ipaddr'} = $node->get('ipmi_ipaddr');
        $nodes{$id}{'ipmi_netmask'} = $node->get('ipmi_netmask');
        
        foreach my $netdev ($node->get('netdevs')) {
            $nodes{$id}{'netdevs'}{$netdev->get('name')} = { 'ipaddr' => 
                $netdev->get('ipaddr'), 'netmask' => $netdev->get('netmask'), 
                'hwaddr' => $netdev->get('hwaddr') };
        }

    }
    return %nodes;
}

sub nodes_hash2 {
    my $nodeSet = shift;
    my %result;
    foreach my $node ($nodeSet->get_list()) {
        my $id = $node->get('_id');
        $result{$id} = $node->get_hash();
    }
    return %result;
}


