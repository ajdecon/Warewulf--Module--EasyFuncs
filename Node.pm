package Node;

use Warewulf::DataStore;
use Warewulf::Provision::Pxelinux;
use Warewulf::Provision::HostsFile;
use Warewulf::Provision::DhcpFactory;
use Warewulf::ParallelCmd;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_nodes nodes_by_cluster get_nodes set_node_properties reboot_nodes);

# get_all_nodes
#   Return full hash of all nodes provisioned by Warewulf.
#   Return nodeid, node name, ip/netmask of eth0,
#   cluster, hwaddr, vnfsid, bootstrapid, fileids.
sub get_all_nodes {
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node','_id',());
    my %nodes = nodes_hash($nodeSet);
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

# reboot_nodes
#   ($lookup, @ident)
sub reboot_nodes {
    my $lookup = shift;
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
            $cmd->queue("ipmitool -I lan -U $username -P $password -H $ipaddr chassis power on");
            $cmd->queue("ipmitool -I lan -U $username -P $password -H $ipaddr chassis power cycle");
            $results{$o->get('_id')}{"status"} = "IPMI on/cycle sent";
        } else {
            $results{$o->get('_id')}{'status'} = "error";
            $results{$o->get('_id')}{'error'} = "Some ipmi variables not set"
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
        $nodes{$id}{'fileids'} = $node->get('fileids') ;
        $nodes{$id}{'user'} = $node->get('user');
        
        foreach my $netdev ($node->get('netdevs')) {
            $nodes{$id}{'netdevs'}{$netdev->get('name')} = { 'ipaddr' => 
                $netdev->get('ipaddr'), 'netmask' => $netdev->get('netmask'), 
                'hwaddr' => $netdev->get('hwaddr') };
        }

    }
    return %nodes;
}
