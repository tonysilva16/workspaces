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

public class Workspaces.Models.Item : Object {
    public string id { get; set; }
    public string name { get; set; }
    public string icon { get; set; }
    public string item_type { get; set; }
    public string command { get; set; }
    public string url { get; set; }
    public bool auto_start { get; set; }
    public bool run_in_terminal { get; set; }
    public Workspaces.Models.AppInfo app_info {get; set;}
    public string directory {get; set;}

    public Item (string name) {
        Object ();
        this.id = Uuid.string_random ();
        this.name = name;
        this.command = "";
        this.item_type = "Custom";
        this.run_in_terminal = false;
        this.auto_start = false;
    }

    public void execute_command () {
        try {
            
            // Used to create new workspace
            if(this.auto_start) {
                Process.spawn_command_line_async ("dbus-send --session --dest=org.pantheon.gala --print-reply /org/pantheon/gala org.pantheon.gala.PerformAction int32:8");
            }

        } catch (SpawnError e) {
            warning ("Error: %s\n", e.message);
        } 

        var to_run_command = prepare_command ();

        if (is_flatpak () == true) {
            to_run_command = "flatpak-spawn --host " + to_run_command;
        }

        try {
            string[] ? argvp = null;
            Shell.parse_argv (to_run_command, out argvp);
            print ("Command to launch: %s\n".printf (to_run_command));
            string[] env = Environ.get ();

            string cdir = GLib.Environment.get_home_dir ();
            Process.spawn_async (cdir,
                                 argvp,
                                 env,
                                 SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL,
                                 null,
                                 null
                                 );
        } catch (SpawnError e) {
            warning ("Error: %s\n", e.message);
        } catch (ShellError e) {
            warning ("Error: %s\n", e.message);
        }
    }

    private string prepare_command () {
        var c = "";
        if (command != null) {
            c = command;
        }

        switch (item_type) {
        case "URL" :
            if (url != null && url.length > 0) {
                c = "xdg-open " + url;
            }
            break;
        case "Directory" :
            if (directory != null && directory.length > 0) {
                c = "xdg-open '" + directory + "'";
            }
            break;
        case "Application" :
            if (app_info != null && app_info.executable.length > 0) {
                c = app_info.executable + " ";
                break;
            } else {
                return "";
            }
        case "ApplicationDirectory" :
            if (app_info != null && app_info.executable != null && app_info.executable.length > 0) {
                var d = "";
                if (directory != null && directory.length > 0) {
                    d = " '" + directory + "'";
                }

                // Is this ok?
                // @@ or %f (Visual studio flatpack) is present sometimes at the end of the command exec
                // Remove it and replace with directory to open
                var exec = app_info.executable;
                var index = app_info.executable.index_of ("@@", 0);
                if(index != -1) {
                    exec = exec.substring (0, index);
                }

                index = app_info.executable.index_of ("%", 0);
                if(index != -1) {
                    exec = exec.substring (0, index);
                }

                c = exec + d;
                break;
            } else {
                return "";
            }
        default :
            c = command;
            break;
        }

        if (run_in_terminal) {
            c = "x-terminal-emulator -e \"%s\"".printf (c.replace ("\"", "\\\""));
        }
        return c;
    }

    public string to_string () {
        return @"[$(this.id)] $(this.name)";
    }
}
