(*
 * $Id$
 *
 * Paparazzi center main module
 *  
 * Copyright (C) 2007 ENAC, Pascal Brisset, Antoine Drouin
 *
 * This file is part of paparazzi.
 *
 * paparazzi is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * paparazzi is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with paparazzi; see the file COPYING.  If not, write to
 * the Free Software Foundation, 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA. 
 *
 *)

open Printf
open Pc_common
module CP = Pc_control_panel
module AC = Pc_aircraft


let () =
  let file = Env.paparazzi_src // "sw" // "supervision" // "paparazzicenter.glade" in
  let gui = new Gtk_pc.window ~file () in
  ignore (gui#window#connect#destroy ~callback:(fun _ -> CP.close_programs gui; exit 0));
  gui#toplevel#show ();

  let ac_combo = AC.parse_conf_xml gui#vbox_ac
  and target_combo = combo ["sim";"fbw";"ap"] gui#vbox_target in

  (combo_widget target_combo)#misc#set_sensitive false;
  gui#button_clean#misc#set_sensitive false;
  gui#button_build#misc#set_sensitive false;

  AC.ac_combo_handler gui ac_combo target_combo;

  AC.conf_handler gui;

  (* Change the buffer of the text view to attach a tag_table *)
  let background_tags = 
    List.map (fun color ->
      let tag = GText.tag ~name:color () in
      tag#set_property (`BACKGROUND color);
      (color, tag))
      ["red"; "green"] in
  let tag_table = GText.tag_table () in
  List.iter (fun (color, tag) -> tag_table#add tag#as_tag) background_tags;
  let buffer = GText.buffer ~tag_table () in
  gui#console#set_buffer buffer;

  let error_regexp = Str.regexp_case_fold ".*\\(error\\)\\|\\(no such file\\)" in
  let compute_tags = fun s ->
    if Str.string_match error_regexp s 0 then
      [List.assoc "red" background_tags]
    else
      [] in

  let log = fun s ->
    let iter = gui#console#buffer#end_iter in
    let tags = compute_tags s in
    gui#console#buffer#insert ~iter ~tags s;
    let iter = gui#console#buffer#end_iter in
    gui#console#buffer#insert ~iter "\n";
    (* Scroll to the bottom line *)
    let end_iter = gui#console#buffer#end_iter in
    let end_mark = gui#console#buffer#create_mark end_iter in
    gui#console#scroll_mark_onscreen (`MARK end_mark) in

  AC.build_handler gui ac_combo target_combo log;

  CP.supervision ~file gui log;

  (* GCS plugin
     Cannot reattach a new window: hack by kill and remake the socket *)
  let rec socket = fun () ->
    let socket_GCS = GWindow.socket ~packing:gui#vbox_GCS#add () in
    CP.socket_GCS_id := socket_GCS#xwindow;
    ignore(socket_GCS#connect#plug_removed 
	     (fun () -> gui#vbox_GCS#remove socket_GCS#coerce; socket ())) in
  socket ();
  
  GMain.Main.main ();;
