package Node;

use Warewulf::DataStore;
use Warewulf::Provision::Pxelinux;
use Warewulf::Provision::HostsFile;
use Warewulf::Provision::DhcpFactory;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_nodes nodes_by_cluster get_nodes set_node_properties);

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
#   ($lookup, @ident, %properties)
sub set_node_properties {
    my $lookup = shift;
    print "lookup = $lookup \n";

    my $i = shift;
    my @ident;
    print "type = " . ref($i) . "\n";
    if (ref($i) eq 'ARRAY') {
        @ident = @{$i};
        print "array = $ident[0]\n";
    } else {
        push(@ident,$ref);
        print "ref = $ref \n";
    }

    my $p = shift;
    print "prop type = " . ref($p) . "\n";
    my %properties = %{$p};

    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node',$lookup,@ident);
    foreach my $n ($nodeSet->get_list()) {
        foreach my $param (keys %properties) {
            $n->set($param,$properties{$param});
        }
    }

    $db->persist($nodeSet);

    return nodes_hash($nodeSet);

}

# nodes_hash
#   Return hash of node details from object set.
sub nodes_hash {
    my $nodeSet = shift;
    my %nodes;
    foreach my $node ($nodeSet->get_list()) {
        my $id = $node->get('name');
        $nodes{$id}{'id'} = $node->get('_id');
        $nodes{$id}{'name'} = $node->get('name');
        $nodes{$id}{'vnfsid'} = $node->get('vnfsid');
        $nodes{$id}{'bootstrapid'} = $node->get('bootstrapid');
        $nodes{$id}{'cluster'} = $node->get('cluster');
        $nodes{$id}{'fileids'} = $node->get('fileids') ;
        
        foreach my $netdev ($node->get('netdevs')) {
            $nodes{$id}{'netdevs'}{$netdev->get('name')} = { 'ipaddr' => 
                $netdev->get('ipaddr'), 'netmask' => $netdev->get('netmask'), 
                'hwaddr' => $netdev->get('hwaddr') };
        }

    }
    return %nodes;
}
