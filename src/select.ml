(* $Id: select.ml,v 4.0 2001-03-16 19:35:00 ddr Exp $ *)
(* Copyright (c) 2001 INRIA *)

open Def;
open Gutil;

value is_censored_person threshold p =
  match Adef.od_of_codate p.birth with
  [ Some date ->
      match date with
      [ Dgreg dmy _ -> dmy.year >= threshold && p.access != Public
      | _ -> False ]
  | None -> False ]
;

value is_censored_couple base threshold cpl =
  let fath = poi base cpl.father in
  let moth = poi base cpl.mother in
  is_censored_person threshold fath || is_censored_person threshold moth
;

value censor_person base per_tab fam_tab flag threshold p no_check =
  let ps = base.data.persons.get p in
  if no_check || is_censored_person threshold ps then
    per_tab.(p) := per_tab.(p) lor flag
  else ()
;

value rec censor_family base per_tab fam_tab flag threshold i no_check =
  let censor_unions p =
    let uni = base.data.unions.get p in
    Array.iter
      (fun ifam ->
         let f = Adef.int_of_ifam ifam in
         do censor_family base per_tab fam_tab flag threshold f True;
            censor_person base per_tab fam_tab flag threshold p True;
         return ())
      uni.family
  in
  let censor_descendants f =
    let des = base.data.descends.get f in
    Array.iter
      (fun iper ->
         let ip = Adef.int_of_iper iper in
         if per_tab.(ip) <> 0 then () else censor_unions ip)
      des.children
  in
  let all_families_censored p =
    let uni = base.data.unions.get p in
    Array.fold_left
      (fun check ifam -> fam_tab.(Adef.int_of_ifam ifam) = 0 && check) True
      uni.family
  in
  let censor_spouse iper =
    let p = Adef.int_of_iper iper in
    if all_families_censored p then per_tab.(p) := per_tab.(p) lor flag
    else ()
  in
  if fam_tab.(i) <> 0 then ()
  else
    let fam = base.data.families.get i in
    if is_deleted_family fam then ()
    else
      let cpl = base.data.couples.get i in
      if no_check || is_censored_couple base threshold cpl then
        do fam_tab.(i) := fam_tab.(i) lor flag;
           censor_spouse cpl.father;
           censor_spouse cpl.mother;
           censor_descendants i;
        return ()
      else ()
;

value censor_base base per_tab fam_tab flag threshold =
  do for i = 0 to base.data.families.len - 1 do
       censor_family base per_tab fam_tab flag threshold i False;
     done;
     for i = 0 to base.data.persons.len - 1 do
       censor_person base per_tab fam_tab flag threshold i False;
     done;
  return ()
;

value flag_family base per_tab fam_tab flag ifam =
  let i = Adef.int_of_ifam ifam in
  let cpl = coi base ifam in
  do fam_tab.(i) := fam_tab.(i) lor flag;
     let i = Adef.int_of_iper cpl.father in
     per_tab.(i) := per_tab.(i) lor flag;
     let i = Adef.int_of_iper cpl.mother in
     per_tab.(i) := per_tab.(i) lor flag;
  return ()
;

value select_ancestors base per_tab fam_tab with_siblings flag iper =
  let rec add_ancestors iper =
    let i = Adef.int_of_iper iper in
    if per_tab.(i) land flag <> 0 then ()
    else
      do per_tab.(i) := per_tab.(i) lor flag; return
      match (aoi base iper).parents with
      [ Some ifam ->
          let i = Adef.int_of_ifam ifam in
          if fam_tab.(i) land flag <> 0 then ()
          else
            do fam_tab.(i) := fam_tab.(i) lor flag; return
            let cpl = coi base ifam in
            do add_ancestors cpl.father;
               add_ancestors cpl.mother;
            return ()
      | None -> () ]
  in
  do add_ancestors iper; return
  if with_siblings then
    let add_sibling_spouse_parents ip =
      match (aoi base ip).parents with
      [ Some ifam -> flag_family base per_tab fam_tab flag ifam
      | None -> () ]
    in
    let add_siblings_marriages ifam =
      let des = doi base ifam in
      Array.iter
        (fun ip ->
           let i = Adef.int_of_iper ip in
           do per_tab.(i) := per_tab.(i) lor flag;
              Array.iter
                (fun ifam ->
                   let i = Adef.int_of_ifam ifam in
                   let cpl = coi base ifam in
                   do fam_tab.(i) := fam_tab.(i) lor flag;
                      List.iter
                        (fun ip ->
                           let i = Adef.int_of_iper ip in
                           do per_tab.(i) := per_tab.(i) lor flag;
                              add_sibling_spouse_parents ip;
                           return ())
                        [cpl.father; cpl.mother];
                   return ())
                (uoi base ip).family;
           return ())
        des.children
    in
    let add_siblings iparent =
      Array.iter
        (fun ifam ->
           do flag_family base per_tab fam_tab flag ifam;
              add_siblings_marriages ifam;
           return ())
        (uoi base iparent).family
    in
    let anc_flag = 4 in
    let rec ancestors_loop iper =
      let i = Adef.int_of_iper iper in
      if per_tab.(i) land anc_flag <> 0 then ()
      else
        do per_tab.(i) := per_tab.(i) lor anc_flag; return
        match (aoi base iper).parents with
        [ Some ifam ->
            let i = Adef.int_of_ifam ifam in
            if fam_tab.(i) land anc_flag <> 0 then ()
            else
              do fam_tab.(i) := fam_tab.(i) lor anc_flag; return
              let cpl = coi base ifam in
              do add_siblings cpl.father;
                 add_siblings cpl.mother;
                 ancestors_loop cpl.father;
                 ancestors_loop cpl.mother;
              return ()
        | None -> () ]
    in
    let rec remove_anc_flag  iper =
      let i = Adef.int_of_iper iper in
      if per_tab.(i) land anc_flag <> 0 then
        do per_tab.(i) := per_tab.(i) land (lnot anc_flag); return
        match (aoi base iper).parents with
        [ Some ifam ->
            let i = Adef.int_of_ifam ifam in
            if fam_tab.(i) land anc_flag <> 0 then
              do fam_tab.(i) := fam_tab.(i) land (lnot anc_flag); return
              let cpl = coi base ifam in
              do remove_anc_flag cpl.father;
                 remove_anc_flag cpl.mother;
              return ()
            else ()
        | None -> () ]
      else ()
    in       
    do ancestors_loop iper;
       remove_anc_flag iper;
    return ()
  else ()
;

value select_descendants base per_tab fam_tab no_spouses_parents flag iper =
  let select_family ifam cpl =
    do let i = Adef.int_of_ifam ifam in fam_tab.(i) := fam_tab.(i) lor flag;
       let i = Adef.int_of_iper cpl.father in
       per_tab.(i) := per_tab.(i) lor flag;
       let i = Adef.int_of_iper cpl.mother in
       per_tab.(i) := per_tab.(i) lor flag;
    return ()
  in
  let rec loop iper =
    let i = Adef.int_of_iper iper in
    if per_tab.(i) land flag <> 0 then ()
    else
      do per_tab.(i) := per_tab.(i) lor flag; return
      Array.iter
        (fun ifam ->
           let i = Adef.int_of_ifam ifam in
           if fam_tab.(i) land flag <> 0 then ()
           else
             let cpl = coi base ifam in
             do select_family ifam cpl;
                if not no_spouses_parents then
                  let sp = spouse iper cpl in
                  match (aoi base sp).parents with
                  [ Some ifam -> select_family ifam (coi base ifam)
                  | None -> () ]
                else ();
             return Array.iter loop (doi base ifam).children)
        (uoi base iper).family
  in
  loop iper
;

value select_descendants_all base per_tab fam_tab no_spouses_parents aflag dflag =
  for i = 0 to base.data.persons.len - 1 do
    if per_tab.(i) land aflag <> 0 then
      select_descendants base per_tab fam_tab no_spouses_parents dflag
        (Adef.iper_of_int i)
    else ();
  done
;

value select_surname base per_tab fam_tab no_spouses_parents surname =
  let surname = Name.strip_lower surname in
  for i = 0 to base.data.families.len - 1 do
    let fam = base.data.families.get i in
    let cpl = base.data.couples.get i in
    if is_deleted_family fam then ()
    else
      let des = base.data.descends.get i in
      let fath = poi base cpl.father in
      let moth = poi base cpl.mother in
      if Name.strip_lower (sou base fath.surname) = surname ||
         Name.strip_lower (sou base moth.surname) = surname then
        do fam_tab.(i) := True;
           per_tab.(Adef.int_of_iper cpl.father) := True;
           per_tab.(Adef.int_of_iper cpl.mother) := True;
           Array.iter
             (fun ic ->
                let p = poi base ic in
                if not per_tab.(Adef.int_of_iper ic) &&
                   Name.strip_lower (sou base p.surname) = surname then
                  per_tab.(Adef.int_of_iper ic) := True
                else ())
             des.children;
           if no_spouses_parents then ()
           else
             List.iter
               (fun x ->
                  match (aoi base x).parents with
                  [ Some ifam when not fam_tab.(Adef.int_of_ifam ifam) ->
                      let cpl = coi base ifam in
                      do fam_tab.(Adef.int_of_ifam ifam) := True;
                         per_tab.(Adef.int_of_iper cpl.father) := True;
                         per_tab.(Adef.int_of_iper cpl.mother) := True;
                      return ()
                  | _ -> () ])
               [cpl.father; cpl.mother];
        return ()
      else ();
  done
;

value functions base anc desc surnames ancdesc no_spouses_parents censor
  with_siblings
=
  let tm = Unix.localtime (Unix.time ()) in
  let threshold = 1900 + tm.Unix.tm_year - censor in
  match (anc, desc, surnames, ancdesc) with
  [ (None, None, [], None) ->
      if censor <> 0 then
        let per_tab = Array.create base.data.persons.len 0 in
        let fam_tab = Array.create base.data.families.len 0 in
        let _ = censor_base base per_tab fam_tab 1 threshold in
        (fun i -> per_tab.(Adef.int_of_iper i) == 0,
         fun i -> fam_tab.(Adef.int_of_ifam i) == 0)
      else (fun _ -> True, fun _ -> True)
  | (None, None, surnames, None) ->
      let per_tab = Array.create base.data.persons.len False in
      let fam_tab = Array.create base.data.families.len False in
      do List.iter (select_surname base per_tab fam_tab no_spouses_parents)
           surnames;
      return
      (fun i -> per_tab.(Adef.int_of_iper i),
       fun i -> fam_tab.(Adef.int_of_ifam i))
  | (None, None, _, Some iadper) ->
      let per_tab = Array.create base.data.persons.len 0 in
      let fam_tab = Array.create base.data.families.len 0 in
      let _ =
        if censor <> 0 then censor_base base per_tab fam_tab 4 threshold
        else ()
      in
      do select_ancestors base per_tab fam_tab False 1 iadper;
         select_descendants_all base per_tab fam_tab no_spouses_parents 1 2;
      return
      (fun i -> let fl = per_tab.(Adef.int_of_iper i) in
                (fl < 4) && (fl > 0),
       fun i -> let fl = fam_tab.(Adef.int_of_ifam i) in
                (fl < 4) && (fl > 0))
  | _ ->
      let per_tab = Array.create base.data.persons.len 0 in
      let fam_tab = Array.create base.data.families.len 0 in
      let _ =
        if censor <> 0 then censor_base base per_tab fam_tab 4 threshold
        else ()
      in
      match (anc, desc) with
      [ (Some iaper, None) ->
          do select_ancestors base per_tab fam_tab with_siblings 1 iaper;
          return
          (fun i -> per_tab.(Adef.int_of_iper i) == 1,
           fun i -> fam_tab.(Adef.int_of_ifam i) == 1)
      | (None, Some idper) ->
          do select_descendants base per_tab fam_tab no_spouses_parents 1
               idper;
          return
          (fun i -> per_tab.(Adef.int_of_iper i) == 1,
           fun i -> fam_tab.(Adef.int_of_ifam i) == 1)
      | (Some iaper, Some idper) ->
          do select_ancestors base per_tab fam_tab False 1 iaper;
             select_descendants base per_tab fam_tab no_spouses_parents 2
               idper;
          return
          (fun i -> per_tab.(Adef.int_of_iper i) == 3,
           fun i -> fam_tab.(Adef.int_of_ifam i) == 3)
      | _ -> assert False ] ]
;
