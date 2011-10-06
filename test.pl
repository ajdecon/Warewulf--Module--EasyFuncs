
use Dancer;
use Dancer::Plugin::REST;
use Node qw(get_all_nodes nodes_by_cluster);
use Vnfs qw(get_all_vnfs);
use Util qw(get_id_by_name);

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

get '/id/:type/:name' => sub {
    my $type = params->{type};
    my $name = params->{name};
    my $id = get_id_by_name($type,$name);
    return { 'id' => $id };
};

dance;
