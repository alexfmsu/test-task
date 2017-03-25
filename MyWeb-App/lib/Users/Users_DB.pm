package Users_DB;

use 5.16.0;
use strict;
use warnings;
use utf8;

use POSIX;
use DBI;

use Moose;

has 'login'=>(
    is=>'ro',
    isa=>'Str',
    required=>1
);

has 'pass'=>(
    is=>'ro',
    isa=>'Str',
    required=>'1'
);

has 'db'=>(
    is=>'rw',
    isa=>'Str',
    required=>'1'
);

has 'dbh'=>(
    is=>'rw',
    isa=>'DBI::db'
);

has 'tb'=>(
    is=>'rw',
    isa=>'Str',
    required=>'1'
);

has 'connected'=>(
    is=>'rw',
    isa=>'Bool',
    default=>0
);

sub connect{
    my $self = shift;
    
    my $login = $self->login;
    my $pass = $self->pass;
    my $db = $self->db;
    
    my $dbh = DBI->connect("DBI:mysql:$db", $login, $pass, {RaiseError=>0, AutoCommit=>1});
    
    if(defined $dbh){
        $self->dbh($dbh);
        $self->connected(1);
    }
}

sub create_database{
    my $self = shift;
    
    my $dbh = $self->dbh;
    my $connected = $self->connected;
    my $db = $self->db;
    
    unless(defined $dbh){
        my $login = $self->login;
        my $pass = $self->pass;
        
        $dbh = DBI->connect("DBI:mysql:", $login, $pass, {RaiseError=>0, AutoCommit=>1}) or die $dbh->errstr;
        
        $dbh->do("CREATE DATABASE $db CHARACTER SET utf8 COLLATE utf8_general_ci") or die $dbh->errstr;
        $dbh->do("USE $db");
        
        $self->dbh($dbh);
        $self->connected(1);
    }else{
        die "Cannot create database database '$db': no connection" unless $connected;
    }
}

sub create_table{
    my $self = shift;
    
    my $dbh = $self->dbh;
    my $connected = $self->connected;
    my $tb = $self->tb;
    
    die "CREATE TABLE failed" unless $connected;
    
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS $tb(
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(12) NOT NULL,
            phone VARCHAR(11),
            created DATETIME DEFAULT NOW()
        ) ENGINE=InnoDB"
    ) or die "Cannot create table $tb: " . $dbh->errstr;
}

sub drop_table{
    my $self = shift;
    
    my $dbh = $self->dbh;
    my $connected = $self->connected;
    my $tb = $self->tb;
    
    die "DROP TABLE failed" unless $connected;
    
    $dbh->do("DROP TABLE IF EXISTS $tb") or die "Cannot drop table $tb: ". $dbh->errstr;
}

sub disconnect{
    my $self = shift;
    
    my $dbh = $self->dbh;
    my $connected = $self->connected;
    my $db = $self->db;
    
    die "Disconnect failed: no connection to the database '$db'" unless $connected;
    
    $dbh->disconnect() or die "Disconnect failed: ". $dbh->errstr;
}

sub generate_data{
    my ($self, $count) = @_;
    
    my $dbh = $self->dbh;
    my $connected = $self->connected;
    my $db = $self->db;
    my $tb = $self->tb;
    
    die "Cannot generate data for table '$tb': no connection to the database '$db'" unless $connected;
    die "Cannot generate data for table '$tb'" unless (defined($count) and $count > 0);
    
    my $raise_error = $dbh->{RaiseError};
    my $print_error = $dbh->{PrintError};
    my $auto_commit = $dbh->{AutoCommit};
    
    $dbh->{RaiseError} = 1;
    $dbh->{PrintError} = 0;
    $dbh->{AutoCommit} = 0;
    
    my $steps;

    if($count < 100_000){
        $steps = 1;
    }else{
        $steps = ceil($count / 100_000);
    }
    
    eval{
        for(1..$steps){
            my $query = "INSERT INTO $tb(name, phone) VALUES";
            
            my $rows;
            
            if($_ != $steps || $count % 100_000 == 0){
                $rows = 100_000;
            }else{
                $rows = $count % 100_000;
            }
            
            for(1..$rows){
                my $name = join '', map{('a'..'z')[rand 26]} 1..12;
                $name = ucfirst($name);
                
                my $phone = join '', map{('0'..'9')[rand 10]} 1..11;
                
                $query .= "('$name', '$phone'),";
            }
            
            chop($query);
            
            $dbh->do($query);
        }
        
        $dbh->do("CREATE INDEX name_index ON $tb(name) USING BTREE");
        $dbh->do("CREATE INDEX phone_index ON $tb(phone) USING BTREE");
        
        $dbh->commit();
    };
    
    if($@){
        die "Cannot generate data for table '$tb': " . $@;
        
        eval{
            $dbh->rollback();
        };
    }
    
    $dbh->{RaiseError} = $raise_error;
    $dbh->{PrintError} = $print_error;
    $dbh->{AutoCommit} = $auto_commit;
}

sub import_from_csv{
    my ($self, $filename) = @_;
    
    my $dbh = $self->dbh;
    my $connected = $self->connected;
    my $db = $self->db;
    my $tb = $self->tb;
    
    die "Cannot import data from file \'$filename\': no connection to the database '$db'" unless $connected;
    
    die "Cannot import data from file \'$filename\'" unless (
        defined $filename and 
        -e $filename and -f $filename and 
        -r $filename and !-z $filename
    );
    
    my $raise_error = $dbh->{RaiseError};
    my $print_error = $dbh->{PrintError};
    my $auto_commit = $dbh->{AutoCommit};
    
    $dbh->{RaiseError} = 1;
    $dbh->{PrintError} = 0;
    $dbh->{AutoCommit} = 0;
    
    eval{
        $dbh->do('
            load data local infile "' . $filename . '" into table '. $tb .
            ' fields terminated by "," lines terminated by "\r\n" (@col1, @col2) set name=@col1, phone=@col2'
        );
        
        $dbh->do("CREATE INDEX name_index ON $tb(name) USING BTREE");
        $dbh->do("CREATE INDEX phone_index ON $tb(phone) USING BTREE");
        
        $dbh->commit();
    };
    
    if($@){
        die "Cannot import data from file \'$filename\': " . $@;
        
        eval{
            $dbh->rollback();
        };
    }
    
    $dbh->{RaiseError} = $raise_error;
    $dbh->{PrintError} = $print_error;
    $dbh->{AutoCommit} = $auto_commit;    
}

sub get_data{
    my ($self, $from, $to) = @_;
    
    my $dbh = $self->dbh;
    my $connected = $self->connected;
    my $db = $self->db;
    my $tb = $self->tb;
    
    die "Cannot get data: no connection to the database '$db'" unless $connected;
    
    die "Cannot get data" unless (defined($from) and defined($to) and ($from >= 0) and ($from <= $to));
    
    my $count = $to - $from;
    
    my $data = $dbh->selectall_arrayref("SELECT * FROM $tb LIMIT $from, $count", {Columns=>{}}) or die $dbh->errstr;
    
    return $data;
}

1;
