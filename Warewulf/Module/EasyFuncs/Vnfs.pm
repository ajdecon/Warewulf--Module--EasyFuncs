package Warewulf::Module::EasyFuncs::Vnfs;

use Warewulf::DataStore;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_vnfs);

sub get_all_vnfs {
    my $db = Warewulf::DataStore->new();
    my $vnfsSet = $db->get_objects('vnfs','_id',());
    return vnfs_hash($vnfsSet);
}

sub vnfs_hash {
    my $vnfsSet = shift;
    my %vnfs;
    foreach my $v ($vnfsSet->get_list()) {
        my $id = $v->get('name');
        $vnfs{$id}{'name'} = $v->get('name');
        $vnfs{$id}{'id'} = $v->get('_id');
        $vnfs{$id}{'size'} = $v->get('size');
    }
    return %vnfs;
}
