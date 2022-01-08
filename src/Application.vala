/*
 * Copyright (c) 2020 - Today Goncalo Margalho (https://github.com/devalien)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Goncalo Margalho <g@margalho.info>
 */

public class Workspaces.Application : Gtk.Application {
    public signal void unselect_all_items (Workspaces.Widgets.WorkspaceRow ? workspace_row);
    public GLib.Settings settings;
    public PreferencesWindow preferences_window;
    public QuickLaunchWindow ql_window;
    public string ? data_dir;

    public Workspaces.Controllers.WorkspacesController workspaces_controller;

    public const string APP_VERSION = "3.1.0";
    public const string APP_ID = "com.github.devalien.workspaces";
    public const string SHOW_WORKSPACES_CMD = APP_ID;
    public const string FLATPAK_SHOW_WORKSPACES_CMD = "flatpak run " + APP_ID;
    private const string SHOW_WORKSPACES_SHORTCUT = "<Control><Alt>w";

    private bool show_quick_launch = false;
    private bool show_settings = false;
    private bool started_settings = false;

    public signal void update_command (string command);
    public Application () {
        Workspaces.Backend.KeyFileFactory.init ();

        Object (
            application_id: APP_ID,
            flags : ApplicationFlags.HANDLES_COMMAND_LINE
            );

        settings = new GLib.Settings (this.application_id);

        data_dir = Path.build_filename (Environment.get_user_data_dir (), application_id);
        print("Data dir %s", data_dir);
        ensure_dir (data_dir);
    }

    public static Application _instance = null;

    public static Application instance {
        get {
            if (_instance == null) {
                _instance = new Application ();
            }
            return _instance;
        }
    }

    public override int command_line (ApplicationCommandLine command_line) {
        show_settings = false;
        show_quick_launch = true;
        started_settings = false;
        bool version = false;

        OptionEntry[] options = new OptionEntry[3];
        options[0] = { "version", 0, 0, OptionArg.NONE, ref version, "Display version number", null };
        options[1] = { "show-quick-launch", 0, 0, OptionArg.NONE, ref show_quick_launch, "Display Quick Launch Window", null };
        options[2] = { "preferences", 0, 0, OptionArg.NONE, ref show_settings, "Display Settings window", null };

        // We have to make an extra copy of the array, since .parse assumes
        // that it can remove strings from the array without freeing them.
        string[] args = command_line.get_arguments ();
        string[] _args = new string[args.length];
        for (int i = 0; i < args.length; i++) {
            _args[i] = args[i];
        }

        try {
            var opt_context = new OptionContext ();
            opt_context.set_help_enabled (true);
            opt_context.add_main_entries (options, null);
            unowned string[] tmp = _args;
            opt_context.parse (ref tmp);
        } catch (OptionError e) {
            command_line.print ("error: %s\n", e.message);
            command_line.print ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
            return 0;
        }

        if (version) {
            command_line.print ("%s\n", APP_VERSION);
            return 0;
        }

        if (show_quick_launch == false) {
            show_settings = true;
            started_settings = true;
        }

        activate ();
        return 0;
    }

    public void load_quick_launch () {
        show_quick_launch = true;
        load_windows ();
    }

    public void load_preferences () {
        show_quick_launch = false;
        load_windows ();
    }

    private void load_windows () {
        var first_run = settings.get_boolean ("first-run");

        if (first_run) {
            set_default_shortcut ();
            settings.set_boolean ("first-run", false);
        }

        if (ql_window != null) {
            remove_window (ql_window);
            ql_window.close ();
            ql_window = null;
        }
        if (preferences_window != null) {
            remove_window (preferences_window);
            preferences_window.close ();
            preferences_window = null;
        }
        if (show_quick_launch) {
            if (ql_window == null) {
                ql_window = new QuickLaunchWindow (first_run);
                add_window (ql_window);
            } else {
                ql_window.present ();
            }
        } else {
            if (preferences_window == null) {
                preferences_window = new PreferencesWindow ();
                add_window (preferences_window);
            } else {
                preferences_window.present ();
            }
        }
    }
    public void close_preferences () {
        if (ql_window != null) {
            remove_window (ql_window);
            ql_window.close ();
            ql_window = null;
        }
        if (preferences_window != null) {
            remove_window (preferences_window);
            preferences_window.close ();
            preferences_window = null;
        }

        if (started_settings == false) {
            load_quick_launch ();
        }
    }
    protected override void activate () {
        var data_file = Path.build_filename (data_dir, "data.json");
        info("Data %s", data_file);
        var store = new Workspaces.Models.Store (data_file);
        workspaces_controller = new Workspaces.Controllers.WorkspacesController (store);

        load_windows ();

        /* Dark Mode support from user settings */
        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        // Then, we check if the user's preference is for the dark style and set it if it is
        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        // Finally, we listen to changes in Granite.Settings and update our app if the user changes their preference
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("com/github/devalien/workspaces/Application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var quit_action = new SimpleAction ("quit", null);

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});

        quit_action.activate.connect (() => {
            if (preferences_window != null) {
                preferences_window.destroy ();
            }
            if (ql_window != null) {
                ql_window.destroy ();
            }
        });
    }

    private void set_default_shortcut () {
        CustomShortcutSettings.init ();
        foreach (var shortcut in CustomShortcutSettings.list_custom_shortcuts ()) {
            if (is_flatpak ()) {
                if (shortcut.command == FLATPAK_SHOW_WORKSPACES_CMD) {
                    CustomShortcutSettings.edit_shortcut (shortcut.relocatable_schema, SHOW_WORKSPACES_SHORTCUT);
                    return;
                }
            } else {
                if (shortcut.command == SHOW_WORKSPACES_CMD) {
                    CustomShortcutSettings.edit_shortcut (shortcut.relocatable_schema, SHOW_WORKSPACES_SHORTCUT);
                    return;
                }
            }
        }
        var shortcut = CustomShortcutSettings.create_shortcut ();
        if (shortcut != null) {
            CustomShortcutSettings.edit_shortcut (shortcut, SHOW_WORKSPACES_SHORTCUT);
            if (is_flatpak ()) {
                CustomShortcutSettings.edit_command (shortcut, FLATPAK_SHOW_WORKSPACES_CMD);
            } else {
                CustomShortcutSettings.edit_command (shortcut, SHOW_WORKSPACES_CMD);
            }
        }
    }

    private void ensure_dir (string path) {
        var dir = File.new_for_path (path);

        try {
            debug (@"Ensuring dir exists: $path");
            dir.make_directory ();
        } catch (Error e) {
            if (!(e is IOError.EXISTS)) {
                warning (@"dir couldn't be created: %s", e.message);
            }
        }
    }
}
