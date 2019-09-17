package With::Roles;
use strict;
use warnings;

our $VERSION = '0.001_000';
$VERSION =~ tr/_//d;

use Carp qw(croak);

my %WITH;

sub with::roles {
  my ($base, @roles) = @_;
  return $base
    if !@roles;
  my $class = ref $base || $base;
  my $with_key = join('|', $class, @roles);
  if (my $new = $WITH{$with_key}) {
    if (ref $base) {
      return bless $_[0], $new;
    }
    return $new;
  }

  my $new;
  my $meta;
  if (
    $INC{'Moo.pm'}
    and Moo->_accessor_maker_for($class)
  ) {
    require Moo::Role;
    my $meth = ref $base ? 'apply_roles_to_object' : 'create_class_with_roles';
    $new = Moo::Role->$meth($_[0], @roles);
  }
  elsif (
    $INC{'Moo/Role.pm'}
    and Moo::Role->is_role($base)
  ) {
    $new = Moo::Role->_composite_name($base, @roles);
    if (Moo::Role->can('make_role')) {
      Moo::Role->make_role($new);
    }
    else {
      my $e;
      {
        local $@;
        eval qq{
          package $new;
          use Moo::Role;
          no Moo::Role;
          1;
        } or $e = $@;
      }
      die $e if defined $e;
    }
    Moo::Role->apply_roles_to_package($new, $base);
    Moo::Role->apply_roles_to_package($new, @roles);
  }
  elsif (
    $INC{'Class/MOP.pm'}
    and $meta = Class::MOP::class_of($base)
    and $meta->isa('Moose::Meta::Role')
  ) {
    $new = Moose::Meta::Role->create_anon_role(roles => [ $base => {} ], cache => 1)->name;
    Moose::Util::apply_all_roles($new, @roles);
  }
  elsif (
    $INC{'Class/MOP.pm'}
    and $meta = Class::MOP::class_of($class)
    and $meta->isa('Class::MOP::Class')
  ) {
    require Moose::Util;
    if (ref $base) {
      Moose::Util::apply_all_roles($base, @roles);
      $new = $base;
    }
    else {
      $new = Moose::Util::with_traits($base, @roles);
    }
  }
  elsif (
    Mouse::Util->can('find_meta')
    and $meta = Mouse::Util::find_meta($base)
    and $meta->isa('Mouse::Meta::Role')
  ) {
    require Mouse::Util;
    $new = Mouse::Meta::Role->create_anon_role(roles => [ $base => {} ], cache => 1)->name;
    Mouse::Util::apply_all_roles($new, @roles);
  }
  elsif (
    Mouse::Util->can('find_meta')
    and $meta = Mouse::Util::find_meta($class)
    and $meta->isa('Mouse::Meta::Class')
  ) {
    if (ref $base) {
      require Mouse::Util;
      Mouse::Util::apply_all_roles($base, @roles);
      $new = $base;
    }
    else {
      $new = (ref $meta)->create_anon_class(
        superclasses => [$base],
        roles        => [@roles],
        cache        => 1,
      )->name;
    }
  }
  elsif (
    $INC{'Role/Tiny.pm'}
    and Role::Tiny->is_role($base)
  ) {
    $new = Role::Tiny->_composite_name($base, @roles);
    if (Role::Tiny->can('make_role')) {
      Role::Tiny->make_role($new);
    }
    else {
      my $e;
      {
        local $@;
        no strict 'refs';
        local *{"${new}::${_}"}
          for keys %{"${new}::"};
        eval qq{
          package $new;
          use Role::Tiny;
          1;
        } or $e = $@;
      }
      die $e if defined $e;
    }
    Role::Tiny->apply_roles_to_package($new, $base);
    Role::Tiny->apply_roles_to_package($new, @roles);
  }
  elsif (
    $INC{'Role/Tiny.pm'}
    and !grep !Role::Tiny->is_role($_), @roles
  ) {
    my $meth = ref $base ? 'apply_roles_to_object' : 'create_class_with_roles';
    $new = Role::Tiny->$meth($_[0], @roles);
  }
  else {
    croak "Can't determine class or role type of $class!";
  }

  my $new_package = ref $new || $new;
  $WITH{$with_key} = $new_package;

  return $new;
}

1;
__END__

=head1 NAME

With::Roles - Create role/class/object with composed roles

=head1 SYNOPSIS

  use With::Roles;
  my $obj = My::Class->with::roles('My::Role')->new;

=head1 DESCRIPTION

When used on classes, generates a subclass with the given roles applied.

When used on roles, generates a new role with the base and given roles applied.

When used on objects, applies the roles to the object and returns the object.

Compatible with Moose, Moo, Mouse, and Role::Tiny roles and classes.

=head1 AUTHOR

haarg - Graham Knop (cpan:HAARG) <haarg@haarg.org>

=head1 CONTRIBUTORS

None so far.

=head1 COPYRIGHT

Copyright (c) 2019 the With::Roles L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<https://dev.perl.org/licenses/>.

=cut
