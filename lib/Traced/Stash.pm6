use v6.d;
use Traced;
unit class Traced::Stash does Traced;

my enum Access <Lookup Assign Bind>;

has Access:D $.access    is required;
has Str:D    $.name      is required;
has Str:D    $.lookup    is required;
has Mu       $.old-value = Nil;
has Mu       $.new-value = Nil;
has Mu       $.result    is required;
has Mu       $.exception is required;
has Bool:D   $.modified  is required;

method new(
    ::?CLASS:_:
    Access:D $access,
    Str:D    $name,
    Str:D    $lookup,
    Mu       $result is raw,
    Mu       $exception is raw,
    *%rest
    --> ::?CLASS:D
) {
    my Bool:D $modified = %rest{<old-value new-value>}:exists.all.so;
    self.bless: :$access, :$name, :$lookup, :$result, :$exception, :$modified, |%rest
}

method colour(::?CLASS:D: --> 32) { }
method key(::?CLASS:D: --> Str:D) { $!access.key.uc }

method success(::?CLASS:D: --> Bool:D) { ! $!exception.DEFINITE }

multi method header(::?CLASS:D: --> Str:D) {
    my Int:D $idx = $!lookup.substr(0, 1) eq <$ @ % &>.any
                 ?? $!lookup.substr(1, 1) eq <* . ! ^ : ? = ~>.any
                    ?? 2
                    !! 1
                 !! 0;
    $idx > 0
        ?? sprintf('%s%s::%s', $!lookup.substr(0, $idx), $!name, $!lookup.substr($idx))
        !! sprintf('%s::%s', $!name, $!lookup)
}

multi method entries(::?CLASS:D $ where { .modified }: Bool:D :$tty! --> Seq:D) {
    gather {
        my Str:D $method = $tty ?? 'gist' !! 'perl';
        take 'old' => $!old-value."$method"();
        take 'new' => $!new-value."$method"();
    }
}

multi method footer(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    $!exception.DEFINITE
        ?? $!exception.^name
        !! $tty
            ?? $!result.gist
            !! $!result.perl
}

my role Mixin {
    multi method AT-KEY(::?CLASS:D: Str:D $lookup --> Mu) is raw {
        my Thread:D  $thread    := $*THREAD;
        my Int:D     $id        := Traced::Stash.next-id;
        my Int:D     $calls     := Traced::Stash.calls: $thread;
        my Instant:D $timestamp := now;
        my Mu        \result     = try callsame;
        Traced::Stash.trace:
            Access::Lookup, self.gist, $lookup, result, $!,
            :$id, :thread-id($thread.id), :$timestamp, :$calls;
        $!.rethrow with $!;
        result
    }

    multi method BIND-KEY(::?CLASS:D: Str:D $lookup, Mu $new-value is raw --> Mu) is raw {
        my Mu        $old-value := self.Stash::AT-KEY: $lookup;
        my Thread:D  $thread    := $*THREAD;
        my Int:D     $id        := Traced::Stash.next-id;
        my Int:D     $calls     := Traced::Stash.calls: $thread;
        my Instant:D $timestamp := now;
        my Mu        \result     = try callsame;
        Traced::Stash.trace:
            Access::Bind, self.gist, $lookup, result, $!,
            :$id, :thread-id($thread.id), :$timestamp, :$calls,
            :$old-value, :$new-value;
        $!.rethrow with $!;
        result
    }

    multi method ASSIGN-KEY(::?CLASS:D: Str:D $lookup, Mu $new-value is raw --> Mu) is raw {
        my Mu        $old-value  = self.Stash::AT-KEY: $lookup; # Intentionally uses $old-value's container.
        my Thread:D  $thread    := $*THREAD;
        my Int:D     $id        := Traced::Stash.next-id;
        my Int:D     $calls     := Traced::Stash.calls: $thread;
        my Instant:D $timestamp := now;
        my Mu        \result     = try callsame;
        Traced::Stash.trace:
            Access::Assign, self.gist, $lookup, result, $!,
            :$id, :thread-id($thread.id), :$timestamp, :$calls,
            :$old-value, :$new-value;
        $!.rethrow with $!;
        result
    }
}

multi method wrap(::?CLASS:U: Stash:D $stash is raw --> Mu) {
    $stash.^mixin: Mixin;
}