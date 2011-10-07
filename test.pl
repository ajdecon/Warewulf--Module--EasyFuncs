
use Dancer;
use Dancer::Plugin::REST;
use Warewulf::Module::EasyFuncs::Node qw(get_all_nodes nodes_by_cluster get_nodes set_node_properties reboot_nodes poweron_nodes poweroff_nodes);
use Warewulf::Module::EasyFuncs::Vnfs qw(get_all_vnfs);
use Warewulf::Module::EasyFuncs::Util qw(get_id_by_name);

set serializer => 'mutable';
set show_errors => 1;

get '/listnodes' => sub {
    my %nodelist = get_all_nodes();
    return { "nodes" => \%nodelist };
};

get '/listvnfs' => sub {
    my %vnfslist = get_all_vnfs();
    return { "vnfs" => \%vnfslist };
};

get '/cluster' => sub {
    my %nodelist = nodes_by_cluster("cloudstacktest");
    return { "nodes" => \%nodelist };
};

get '/specnode/:name' => sub {
    my $name = params->{name};
    my @nodes = ("$name");
    #my @nodes = ("wd0031");
    my %nodelist = get_nodes("name",\@nodes);
    return { "nodes" => \%nodelist };
};

get '/test' => sub {
    my %props;
    $props{'14'}{'cluster'} = 'testagain';
    $props{'15'}{'cluster'} = 'yetagain';
    $props{'14'}{'netdevs'}{'eth0'}{'ipaddr'} = '10.8.47.1';
    #my @fids = (14,15,16);
    #$props{'15'}{'fileids'} = \@fids;
    my %result = set_node_properties("name", \%props);
    return { "nodes" => \%result, "propinput" => \%props };
};
get '/on' => sub {
    my @nodelist = ("wd0031","wd0032","wd0033");
    my %result = poweron_nodes("name",\@nodelist);
    return { "result" => \%result };
};


get '/reboot' => sub {
    my @nodelist = ("wd0031","wd0032","wd0033");
    my %result = reboot_nodes("name",\@nodelist);
    return { "result" => \%result };
};

get '/id/:type/:name' => sub {
    my $type = params->{type};
    my $name = params->{name};
    my $id = get_id_by_name($type,$name);
    return { 'id' => $id };
};

dance;
