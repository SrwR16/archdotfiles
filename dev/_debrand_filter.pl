#!/usr/bin/env perl
# Ordered, literal (\Q..\E) de-branding replacements.
# Used for BOTH file contents and basenames so there is a single source of
# truth. Order matters: most-specific compounds first, generic catch-alls last.
use strict;
use warnings;

my @rules = (
    # --- URLs / domains (before any ml4w token catch-all) ---
    ['https://ml4w.com/os/getting-started/dependencies', 'https://github.com/SrwR16/archdotfiles'],
    ['https://ml4w.com/os/getting-started/update',       'https://github.com/SrwR16/archdotfiles'],
    ['https://ml4w.com/os/',                             'https://github.com/SrwR16/archdotfiles'],
    ['ml4w.com',                                         'github.com/SrwR16/archdotfiles'],

    # --- reverse-DNS ids (dotted + GResource slashed forms) ---
    ['com.ml4w.dotfiles',           'com.dotfiles.hyprland'],
    ['com/ml4w/hyprlandsettings',   'com/dotfiles/hyprlandsettings'],
    ['com.ml4w.hyprlandsettings',   'com.dotfiles.hyprlandsettings'],

    # --- compound names (before the generic ml4w- prefix strip) ---
    ['ml4w-dotfiles-settings',  'dotfiles-settings'],
    ['ml4w-dotfiles-installer', 'dotfiles-installer'],
    ['ml4w-statusbar',          'dotfiles-statusbar'],
    ['ml4w-tmp',                'dotfiles-tmp'],
    ['ml4w-dotfiles',           'dotfiles'],

    # --- vendored app dir names (xi-*) ---
    ['xi-dotfiles-settings',  'dotfiles-settings'],
    ['xi-hyprland-settings',  'hyprland-settings'],
    ['xi-nvim',               'nvim'],
    ['xi-sddm',               'sddm'],

    # --- filesystem paths ---
    ['.config/ml4w',       '.config/dotfiles'],
    ['.cache/ml4w',        '.cache/dotfiles'],
    ['.local/share/ml4w',  '.local/share/dotfiles'],

    # --- QML wrapper components (before generic ML4W text) ---
    ['ML4WMenuItem',      'ShellMenuItem'],
    ['ML4WMenuSeparator', 'ShellMenuSeparator'],
    ['ML4WMenu',          'ShellMenu'],
    ['ML4WSwitch',        'ShellSwitch'],
    ['ML4WButton',        'ShellButton'],
    ['ML4WComboBox',      'ShellComboBox'],
    ['ML4WCheckBox',      'ShellCheckBox'],

    # --- CamelCase logo module ---
    ['Ml4wLogoModule', 'LogoModule'],
    ['Ml4w',           'Dotfiles'],

    # --- generic script prefix strip ---
    ['ml4w-', ''],

    # --- residual branding text / lowercase tokens ---
    ['ML4W', 'Dotfiles'],
    ['ml4w', 'dotfiles'],
);

while (my $line = <>) {
    for my $r (@rules) {
        my ($from, $to) = @$r;
        $line =~ s/\Q$from\E/$to/g;
    }
    print $line;
}
