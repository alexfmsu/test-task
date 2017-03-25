package MyWeb::App;

use Dancer2;
use POSIX;
use Config::Simple;

use Time::HiRes qw(gettimeofday tv_interval);
use lib::Users::Users_DB;

our $VERSION = '0.1';

# -----------------------------------------
my $cfg = new Config::Simple('lib/Users/config.ini') or die "Cannot read config file";

my $login = $cfg->param('login');
my $pass = $cfg->param('pass');
my $host = $cfg->param('host');
my $db = $cfg->param('db');
my $tb = $cfg->param('tb');
# -----------------------------------------

my $rows_total = 3_000_000;
my $rows_limit = 3_000;

my $data;

my $tabs_count;

sub tabs_shown{20};

get '/'=>sub {
    template 'index'
};

get '/generate'=>sub {
    my $connection = Users_DB->new(login=>$login, pass=>$pass, db=>$db, tb=>$tb);
    
    $connection->connect();
    
    $connection->create_database();
    $connection->drop_table();
    $connection->create_table();
    
    # my $start_time = [gettimeofday];
    
    $connection->generate_data($rows_total);
    
    # my $end_time = [gettimeofday];
    
    # my $time = tv_interval($start_time,$end_time);
    
    $connection->disconnect();
    
    template 'index';
    # template 'index'=>{'PERL_DATA'=>$time};
};

get '/import'=>sub {
    my $connection = Users_DB->new(login=>$login, pass=>$pass, db=>$db, tb=>$tb);
    
    $connection->connect();
    
    $connection->create_database();
    $connection->drop_table();
    $connection->create_table();
    
    # my $start_time = [gettimeofday];
    
    $connection->import_from_csv('lib/Users/data.csv');
    
    # my $end_time = [gettimeofday];
    
    # my $time = tv_interval($start_time,$end_time);
    
    $connection->disconnect();
    
    template 'index';
    # template 'index'=>{'PERL_DATA'=>$time};
};

get '/print'=>sub {
    my $connection = Users_DB->new(login=>$login, pass=>$pass, db=>$db, tb=>$tb);
    
    $tabs_count = ceil($rows_total / $rows_limit);
    
    init_pages();
    
    redirect '/0';
};

get '/left'=>sub {
    redirect '/0';
};

get '/right'=>sub {
    redirect '/' . ($tabs_count - 1);
};

sub init_pages{
    for my $i(0..$tabs_count){
        get "/$i"=>sub {
            my $connection = Users_DB->new(login=>$login, pass=>$pass, db=>$db, tb=>$tb);
            
            $connection->connect();
            
            my $select_from = $i * $rows_limit;
            my $select_to = $select_from + $rows_limit;
            
            $data = $connection->get_data($select_from, $select_to);
            
            $connection->disconnect();
            
            my $table;
            
            my $tab_start = 0;
            
            if($i >= tabs_shown() / 2){
                $tab_start = $i - tabs_shown() / 2;
            }
            
            my $tab_fin = $tab_start + tabs_shown() - 1;
            
            if($tab_fin >= $tabs_count - 1){
                $tab_fin = $tabs_count - 1;
                $tab_start = $tab_fin - tabs_shown() + 1;
            }
            
            $table .= "<a href=/left class='tab_button'>&laquo;</a>";
            
            for($tab_start..$tab_fin){
                $table .= "<a href=/$_ class='tab_button'>$_</a>";
            }
            
            $table .= "<a href=/right class='tab_button'>&raquo;</a>";
            
            $table .= "<p>";
            
            $table .= '<table class="users_table">';
            
            $table .= '<tr>';
                $table .= '<td>ID</td>';
                $table .= '<td>Name</td>';
                $table .= '<td>Phone</td>';
                $table .= '<td>Created</td>';
            $table .= '</tr>';
            
            for(@$data){
                $table .= '<tr>';
                    $table .= '<td>'.($_->{id})."</td>";
                    $table .= '<td>'.($_->{name})."</td>";
                    $table .= '<td>'.($_->{phone})."</td>";
                    $table .= '<td>'.($_->{created})."</td>";
                $table .= '</tr>';
            }
            
            $table .= '</table>';
            
            template 'index'=>{'PERL_DATA'=>$table};
        }
    }
}

1;
