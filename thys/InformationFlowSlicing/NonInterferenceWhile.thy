section {* Information Flow for While *}

theory NonInterferenceWhile imports
  "../Slicing/While/SemanticsWellFormed"
  "../Slicing/While/StaticControlDependences"
  LiftingIntra
begin

locale SecurityTypes =
  fixes H :: "vname set"
  fixes L :: "vname set"
  assumes HighLowDistinct: "H \<inter> L = {}"
  and HighLowUNIV: "H \<union> L = UNIV"
begin


subsection {* Lifting @{term labels_nodes} and Defining @{text final} *}

fun labels_LDCFG_nodes :: "cmd \<Rightarrow> w_node LDCFG_node \<Rightarrow> cmd \<Rightarrow> bool"
  where "labels_LDCFG_nodes prog (Node n) c = labels_nodes prog n c"
  | "labels_LDCFG_nodes prog n c = False"



lemmas WCFG_path_induct[consumes 1, case_names empty_path Cons_path]
  = CFG.path.induct[OF While_CFG_aux]


lemma lift_valid_node:
  assumes "CFG.valid_node sourcenode targetnode (valid_edge prog) n"
  shows "CFG.valid_node src trg
  (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
  (Node n)"
proof -
  from `CFG.valid_node sourcenode targetnode (valid_edge prog) n`
  obtain a where "valid_edge prog a" and "n = sourcenode a \<or> n = targetnode a"
    by(fastforce simp:While_CFG.valid_node_def)
  from `n = sourcenode a \<or> n = targetnode a`
  show ?thesis
  proof
    assume "n = sourcenode a"
    show ?thesis
    proof(cases "sourcenode a = Entry")
      case True
      have "lift_valid_edge (valid_edge prog) sourcenode targetnode kind Entry Exit 
        (NewEntry,(\<lambda>s. True)\<^sub>\<surd>,Node Entry)"
        by(fastforce intro:lve_Entry_edge)
      with While_CFGExit_wf_aux[of prog] `n = sourcenode a` True show ?thesis
        by(fastforce simp:CFG.valid_node_def[OF lift_CFG])
    next
      case False
      with `valid_edge prog a` `n = sourcenode a \<or> n = targetnode a`
      have "lift_valid_edge (valid_edge prog) sourcenode targetnode kind Entry Exit 
        (Node (sourcenode a),kind a,Node (targetnode a))"
        by(fastforce intro:lve_edge)
      with While_CFGExit_wf_aux[of prog] `n = sourcenode a` show ?thesis
        by(fastforce simp:CFG.valid_node_def[OF lift_CFG])
    qed
  next
    assume "n = targetnode a"
    show ?thesis
    proof(cases "targetnode a = Exit")
      case True
      have "lift_valid_edge (valid_edge prog) sourcenode targetnode kind Entry Exit 
        (Node Exit,(\<lambda>s. True)\<^sub>\<surd>,NewExit)"
        by(fastforce intro:lve_Exit_edge)
      with While_CFGExit_wf_aux[of prog] `n = targetnode a` True show ?thesis
        by(fastforce simp:CFG.valid_node_def[OF lift_CFG])
    next
      case False
      with `valid_edge prog a` `n = sourcenode a \<or> n = targetnode a`
      have "lift_valid_edge (valid_edge prog) sourcenode targetnode kind Entry Exit 
        (Node (sourcenode a),kind a,Node (targetnode a))"
        by(fastforce intro:lve_edge)
      with While_CFGExit_wf_aux[of prog] `n = targetnode a` show ?thesis
        by(fastforce simp:CFG.valid_node_def[OF lift_CFG])
    qed
  qed
qed



lemma lifted_CFG_fund_prop:
  assumes "labels_LDCFG_nodes prog n c" and "\<langle>c,s\<rangle> \<rightarrow>* \<langle>c',s'\<rangle>"
  shows "\<exists>n' as. CFG.path src trg
  (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
  n as n' \<and> transfers (CFG.kinds knd as) s = s' \<and>
  preds (CFG.kinds knd as) s \<and> labels_LDCFG_nodes prog n' c'"
proof -
  from `labels_LDCFG_nodes prog n c` obtain nx where "n = Node nx"
    and "labels_nodes prog nx c" by(cases n) auto
  from `labels_nodes prog nx c` `\<langle>c,s\<rangle> \<rightarrow>* \<langle>c',s'\<rangle>`
  obtain n' as where "prog \<turnstile> nx -as\<rightarrow>* n'" and "transfers (CFG.kinds kind as) s = s'"
    and "preds (CFG.kinds kind as) s" and "labels_nodes prog n' c'"
    by(auto dest:While_semantics_CFG_wf.fundamental_property)
  from `labels_nodes prog n' c'` have "labels_LDCFG_nodes prog (Node n') c'"
    by simp
  from `prog \<turnstile> nx -as\<rightarrow>* n'` `transfers (CFG.kinds kind as) s = s'` 
    `preds (CFG.kinds kind as) s` `n = Node nx`
    `labels_nodes prog nx c` `labels_nodes prog n' c'`
  have "\<exists>es. CFG.path src trg
    (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
    (Node nx) es (Node n') \<and> transfers (CFG.kinds knd es) s = s' \<and>
    preds (CFG.kinds knd es) s"
  proof(induct arbitrary:n s c rule:WCFG_path_induct)
    case (empty_path n nx)
    from `CFG.valid_node sourcenode targetnode (valid_edge prog) n`
    have valid_node:"CFG.valid_node src trg
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
      (Node n)"
      by(rule lift_valid_node)
    have "CFG.kinds knd 
      ([]::(w_node LDCFG_node \<times> state edge_kind \<times> w_node LDCFG_node) list) = []"
      by(simp add:CFG.kinds_def[OF lift_CFG[OF While_CFGExit_wf_aux]])
    with `transfers (CFG.kinds kind []) s = s'` `preds (CFG.kinds kind []) s`
      valid_node
    show ?case
      by(fastforce intro:CFG.empty_path[OF lift_CFG[OF While_CFGExit_wf_aux]] 
                   simp:While_CFG.kinds_def)
  next
    case (Cons_path n'' as n' a nx)
    note IH = `\<And>n s c. \<lbrakk>transfers (CFG.kinds kind as) s = s'; 
      preds (CFG.kinds kind as) s; n = LDCFG_node.Node n''; 
      labels_nodes prog n'' c; labels_nodes prog n' c'\<rbrakk>
      \<Longrightarrow> \<exists>es. CFG.path src trg
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
      (LDCFG_node.Node n'') es (LDCFG_node.Node n') \<and>
      transfers (CFG.kinds knd es) s = s' \<and> preds (CFG.kinds knd es) s`
    from `transfers (CFG.kinds kind (a # as)) s = s'`
    have "transfers (CFG.kinds kind as) (transfer (kind a) s) = s'"
      by(simp add:While_CFG.kinds_def)
    from `preds (CFG.kinds kind (a # as)) s`
    have "preds (CFG.kinds kind as) (transfer (kind a) s)"
      and "pred (kind a) s" by(simp_all add:While_CFG.kinds_def)
    show ?case
    proof(cases "sourcenode a = (_Entry_)")
      case True
      with `sourcenode a = nx` `labels_nodes prog nx c` have False by simp
      thus ?thesis by simp
    next
      case False
      with `valid_edge prog a`
      have edge:"lift_valid_edge (valid_edge prog) sourcenode targetnode kind 
        Entry Exit (Node (sourcenode a),kind a,Node (targetnode a))"
        by(fastforce intro:lve_edge)
      from `prog \<turnstile> n'' -as\<rightarrow>* n'`
      have "CFG.valid_node sourcenode targetnode (valid_edge prog) n''"
        by(rule While_CFG.path_valid_node)
      then obtain c'' where "labels_nodes prog n'' c''"
      proof(cases rule:While_CFGExit.valid_node_cases)
        case Entry
        with `targetnode a = n''` `valid_edge prog a` have False by fastforce
        thus ?thesis by simp
      next
        case Exit
        with `prog \<turnstile> n'' -as\<rightarrow>* n'` have "n' = (_Exit_)" by fastforce
        with `labels_nodes prog n' c'` have False by fastforce
        thus ?thesis by simp
      next
        case inner
        then obtain l'' where [simp]:"n'' = (_ l'' _)" by(cases n'') auto
        with `valid_edge prog a` `targetnode a = n''` have "l'' < #:prog"
          by(fastforce intro:WCFG_targetlabel_less_num_nodes simp:valid_edge_def)
        then obtain c'' where "labels prog l'' c''"
          by(fastforce dest:less_num_inner_nodes_label)
        with that show ?thesis by fastforce
      qed
      from IH[OF `transfers (CFG.kinds kind as) (transfer (kind a) s) = s'`
        `preds (CFG.kinds kind as) (transfer (kind a) s)` _ this 
        `labels_nodes prog n' c'`]
      obtain es where "CFG.path src trg
        (lift_valid_edge (valid_edge prog) sourcenode targetnode kind 
        (_Entry_) (_Exit_)) (LDCFG_node.Node n'') es (LDCFG_node.Node n')"
        and "transfers (CFG.kinds knd es) (transfer (kind a) s) = s'"
        and "preds (CFG.kinds knd es) (transfer (kind a) s)" by blast
      with `targetnode a = n''` `sourcenode a = nx` edge
      have path:"CFG.path src trg
        (lift_valid_edge (valid_edge prog) sourcenode targetnode 
        kind (_Entry_) (_Exit_))
        (LDCFG_node.Node nx) ((Node (sourcenode a),kind a,Node (targetnode a))#es) 
        (LDCFG_node.Node n')"
        by(fastforce intro:CFG.Cons_path[OF lift_CFG[OF While_CFGExit_wf_aux]])
      from edge have "knd (Node (sourcenode a),kind a,Node (targetnode a)) = kind a"
        by(simp add:knd_def)
      with `transfers (CFG.kinds knd es) (transfer (kind a) s) = s'`
        `preds (CFG.kinds knd es) (transfer (kind a) s)` `pred (kind a) s`
      have "transfers 
        (CFG.kinds knd ((Node (sourcenode a),kind a,Node (targetnode a))#es)) s = s'"
        and "preds 
        (CFG.kinds knd ((Node (sourcenode a),kind a,Node (targetnode a))#es)) s"
        by(auto simp:CFG.kinds_def[OF lift_CFG[OF While_CFGExit_wf_aux]])
      with path show ?thesis by blast
    qed
  qed
  with `n = Node nx` `labels_LDCFG_nodes prog (Node n') c'`
  show ?thesis by fastforce
qed



fun final :: "cmd \<Rightarrow> bool"
  where "final Skip = True"
  | "final c = False"


lemma final_edge:
  "labels_nodes prog n Skip \<Longrightarrow> prog \<turnstile> n -\<Up>id\<rightarrow> (_Exit_)"
proof(induct prog arbitrary:n)
  case Skip
  from `labels_nodes Skip n Skip` have "n = (_ 0 _)" 
    by(cases n)(auto elim:labels.cases)
  thus ?case by(fastforce intro:WCFG_Skip)
next
  case (LAss V e)
  from `labels_nodes (V:=e) n Skip` have "n = (_ 1 _)" 
    by(cases n)(auto elim:labels.cases)
  thus ?case by(fastforce intro:WCFG_LAssSkip)
next
  case (Seq c\<^sub>1 c\<^sub>2)
  note IH2 = `\<And>n. labels_nodes c\<^sub>2 n Skip \<Longrightarrow> c\<^sub>2 \<turnstile> n -\<Up>id\<rightarrow> (_Exit_)`
  from `labels_nodes (c\<^sub>1;; c\<^sub>2) n Skip` obtain l where "n = (_ l _)"
    and "l \<ge> #:c\<^sub>1" and "labels_nodes c\<^sub>2 (_ l - #:c\<^sub>1 _) Skip"
    by(cases n)(auto elim:labels.cases)
  from IH2[OF `labels_nodes c\<^sub>2 (_ l - #:c\<^sub>1 _) Skip`]
  have "c\<^sub>2 \<turnstile> (_ l - #:c\<^sub>1 _) -\<Up>id\<rightarrow> (_Exit_)" .
  with `l \<ge> #:c\<^sub>1` have "c\<^sub>1;;c\<^sub>2 \<turnstile> (_ l - #:c\<^sub>1 _) \<oplus> #:c\<^sub>1 -\<Up>id\<rightarrow> (_Exit_) \<oplus> #:c\<^sub>1"
    by(fastforce intro:WCFG_SeqSecond)
  with `n = (_ l _)` `l \<ge> #:c\<^sub>1` show ?case by(simp add:id_def)
next
  case (Cond b c\<^sub>1 c\<^sub>2)
  note IH1 = `\<And>n. labels_nodes c\<^sub>1 n Skip \<Longrightarrow> c\<^sub>1 \<turnstile> n -\<Up>id\<rightarrow> (_Exit_)`
  note IH2 = `\<And>n. labels_nodes c\<^sub>2 n Skip \<Longrightarrow> c\<^sub>2 \<turnstile> n -\<Up>id\<rightarrow> (_Exit_)`
  from `labels_nodes (if (b) c\<^sub>1 else c\<^sub>2) n Skip`
  obtain l where "n = (_ l _)" and disj:"(l \<ge> 1 \<and> labels_nodes c\<^sub>1 (_ l - 1 _) Skip) \<or>
    (l \<ge> #:c\<^sub>1 + 1 \<and> labels_nodes c\<^sub>2 (_ l - #:c\<^sub>1 - 1 _) Skip)"
    by(cases n) (fastforce elim:labels.cases)+
  from disj show ?case
  proof
    assume "1 \<le> l \<and> labels_nodes c\<^sub>1 (_ l - 1 _) Skip"
    hence "1 \<le> l" and "labels_nodes c\<^sub>1 (_ l - 1 _) Skip" by simp_all
    from IH1[OF `labels_nodes c\<^sub>1 (_ l - 1 _) Skip`] 
    have "c\<^sub>1 \<turnstile> (_ l - 1 _) -\<Up>id\<rightarrow> (_Exit_)" .
    with `1 \<le> l` have "if (b) c\<^sub>1 else c\<^sub>2 \<turnstile> (_ l - 1 _) \<oplus> 1 -\<Up>id\<rightarrow> (_Exit_) \<oplus> 1"
      by(fastforce intro:WCFG_CondThen)
    with `n = (_ l _)` `1 \<le> l` show ?case by(simp add:id_def)
  next
    assume "#:c\<^sub>1 + 1 \<le> l \<and> labels_nodes c\<^sub>2 (_ l - #:c\<^sub>1 - 1 _) Skip"
    hence "#:c\<^sub>1 + 1 \<le> l" and "labels_nodes c\<^sub>2 (_ l - #:c\<^sub>1 - 1 _) Skip" by simp_all
    from IH2[OF `labels_nodes c\<^sub>2 (_ l - #:c\<^sub>1 - 1 _) Skip`]
    have "c\<^sub>2 \<turnstile> (_ l - #:c\<^sub>1 - 1 _) -\<Up>id\<rightarrow> (_Exit_)" .
    with `#:c\<^sub>1 + 1 \<le> l` have "if (b) c\<^sub>1 else c\<^sub>2 \<turnstile> (_ l - #:c\<^sub>1 - 1 _) \<oplus> (#:c\<^sub>1 + 1)
      -\<Up>id\<rightarrow> (_Exit_) \<oplus> (#:c\<^sub>1 + 1)"
      by(fastforce intro:WCFG_CondElse)
    with `n = (_ l _)` `#:c\<^sub>1 + 1 \<le> l` show ?case by(simp add:id_def)
  qed
next
  case (While b c)
  from `labels_nodes (while (b) c) n Skip` have "n = (_ 1 _)" 
    by(cases n)(auto elim:labels.cases)
  thus ?case by(fastforce intro:WCFG_WhileFalseSkip)
qed




subsection {* Semantic Non-Interference for Weak Order Dependence *}

lemmas WODNonInterferenceGraph = 
  lift_wod_backward_slice[OF While_CFGExit_wf_aux HighLowDistinct HighLowUNIV]


lemma WODNonInterference:
  "NonInterferenceIntra src trg knd
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
       (_Entry_) (_Exit_))
     NewEntry (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
     (lift_Use (Uses prog) (_Entry_) (_Exit_) H L) id
     (CFG_wf.wod_backward_slice src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L))
     reds (labels_LDCFG_nodes prog)
     NewExit H L (LDCFG_node.Node (_Entry_)) (LDCFG_node.Node (_Exit_)) final"
proof -
  interpret NonInterferenceIntraGraph src trg knd
     "lift_valid_edge (valid_edge prog) sourcenode targetnode kind
       (_Entry_) (_Exit_)"
     NewEntry "lift_Def (Defs prog) (_Entry_) (_Exit_) H L"
     "lift_Use (Uses prog) (_Entry_) (_Exit_) H L" id
     "CFG_wf.wod_backward_slice src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)"
     NewExit H L "LDCFG_node.Node (_Entry_)" "LDCFG_node.Node (_Exit_)"
    by(rule WODNonInterferenceGraph)
  interpret BackwardSlice_wf src trg knd
    "lift_valid_edge (valid_edge prog) sourcenode targetnode kind
      (_Entry_) (_Exit_)"
    NewEntry "lift_Def (Defs prog) (_Entry_) (_Exit_) H L"
    "lift_Use (Uses prog) (_Entry_) (_Exit_) H L" id
    "CFG_wf.wod_backward_slice src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)" reds "labels_LDCFG_nodes prog"
  proof(unfold_locales)
    fix n c s c' s'
    assume "labels_LDCFG_nodes prog n c" and "\<langle>c,s\<rangle> \<rightarrow>* \<langle>c',s'\<rangle>"
    thus "\<exists>n' as. CFG.path src trg
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
      n as n' \<and> transfers (CFG.kinds knd as) s = s' \<and>
      preds (CFG.kinds knd as) s \<and> labels_LDCFG_nodes prog n' c'"
      by(rule lifted_CFG_fund_prop)
  qed
  show ?thesis 
  proof(unfold_locales)
    fix c n
    assume "final c" and "labels_LDCFG_nodes prog n c"
    from `final c` have [simp]:"c = Skip" by(cases c) auto
    from `labels_LDCFG_nodes prog n c` obtain nx where [simp]:"n = Node nx"
      and "labels_nodes prog nx Skip" by(cases n) auto
    from `labels_nodes prog nx Skip` have "prog \<turnstile> nx -\<Up>id\<rightarrow> (_Exit_)"
      by(rule final_edge)
    then obtain a where "valid_edge prog a" and "sourcenode a = nx"
      and "kind a = \<Up>id" and "targetnode a = (_Exit_)"
      by(auto simp:valid_edge_def)
    with `labels_nodes prog nx Skip`
    show "\<exists>a. lift_valid_edge (valid_edge prog) sourcenode targetnode
      kind (_Entry_) (_Exit_) a \<and>
      src a = n \<and> trg a = LDCFG_node.Node (_Exit_) \<and> knd a = \<Up>id"
      by(rule_tac x="(Node nx,\<Up>id,Node (_Exit_))" in exI)
        (auto intro!:lve_edge simp:knd_def valid_edge_def)
  qed
qed


subsection {* Semantic Non-Interference for Standard Control Dependence *}

lemma inner_node_exists:"\<exists>n. CFGExit.inner_node sourcenode targetnode 
  (valid_edge prog) (_Entry_) (_Exit_) n"
proof -
  have "prog \<turnstile> (_Entry_) -(\<lambda>s. True)\<^sub>\<surd>\<rightarrow> (_0_)" by(rule WCFG_Entry)
  hence "CFG.valid_node sourcenode targetnode (valid_edge prog) (_0_)"
    by(auto simp:While_CFG.valid_node_def valid_edge_def)
  thus ?thesis by(auto simp:While_CFGExit.inner_node_def)
qed


lemmas SCDNonInterferenceGraph = 
  lift_PDG_standard_backward_slice[OF WStandardControlDependence.PDG_scd 
  WhilePostdomination_aux _ HighLowDistinct HighLowUNIV]


lemma SCDNonInterference:
  "NonInterferenceIntra src trg knd
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
       (_Entry_) (_Exit_))
     NewEntry (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
     (lift_Use (Uses prog) (_Entry_) (_Exit_) H L) id
     (PDG.PDG_BS src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)
       (Postdomination.standard_control_dependence src trg
         (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
           (_Entry_) (_Exit_)) NewExit))
     reds (labels_LDCFG_nodes prog)
     NewExit H L (LDCFG_node.Node (_Entry_)) (LDCFG_node.Node (_Exit_)) final"
proof -
  from inner_node_exists obtain n where "CFGExit.inner_node sourcenode targetnode 
    (valid_edge prog) (_Entry_) (_Exit_) n" by blast
  then interpret NonInterferenceIntraGraph src trg knd
     "lift_valid_edge (valid_edge prog) sourcenode targetnode kind
       (_Entry_) (_Exit_)"
     NewEntry "lift_Def (Defs prog) (_Entry_) (_Exit_) H L"
     "lift_Use (Uses prog) (_Entry_) (_Exit_) H L" id
     "PDG.PDG_BS src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)
       (Postdomination.standard_control_dependence src trg
         (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
           (_Entry_) (_Exit_)) NewExit)"
     NewExit H L "LDCFG_node.Node (_Entry_)" "LDCFG_node.Node (_Exit_)"
    by(fastforce intro:SCDNonInterferenceGraph)
  interpret BackwardSlice_wf src trg knd
    "lift_valid_edge (valid_edge prog) sourcenode targetnode kind
      (_Entry_) (_Exit_)"
    NewEntry "lift_Def (Defs prog) (_Entry_) (_Exit_) H L"
    "lift_Use (Uses prog) (_Entry_) (_Exit_) H L" id
    "PDG.PDG_BS src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)
       (Postdomination.standard_control_dependence src trg
         (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
           (_Entry_) (_Exit_)) NewExit)" reds "labels_LDCFG_nodes prog"
  proof(unfold_locales)
    fix n c s c' s'
    assume "labels_LDCFG_nodes prog n c" and "\<langle>c,s\<rangle> \<rightarrow>* \<langle>c',s'\<rangle>"
    thus "\<exists>n' as. CFG.path src trg
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
      n as n' \<and> transfers (CFG.kinds knd as) s = s' \<and>
      preds (CFG.kinds knd as) s \<and> labels_LDCFG_nodes prog n' c'"
      by(rule lifted_CFG_fund_prop)
  qed
  show ?thesis 
  proof(unfold_locales)
    fix c n
    assume "final c" and "labels_LDCFG_nodes prog n c"
    from `final c` have [simp]:"c = Skip" by(cases c) auto
    from `labels_LDCFG_nodes prog n c` obtain nx where [simp]:"n = Node nx"
      and "labels_nodes prog nx Skip" by(cases n) auto
    from `labels_nodes prog nx Skip` have "prog \<turnstile> nx -\<Up>id\<rightarrow> (_Exit_)"
      by(rule final_edge)
    then obtain a where "valid_edge prog a" and "sourcenode a = nx"
      and "kind a = \<Up>id" and "targetnode a = (_Exit_)"
      by(auto simp:valid_edge_def)
    with `labels_nodes prog nx Skip`
    show "\<exists>a. lift_valid_edge (valid_edge prog) sourcenode targetnode
      kind (_Entry_) (_Exit_) a \<and>
      src a = n \<and> trg a = LDCFG_node.Node (_Exit_) \<and> knd a = \<Up>id"
      by(rule_tac x="(Node nx,\<Up>id,Node (_Exit_))" in exI)
        (auto intro!:lve_edge simp:knd_def valid_edge_def)
  qed
qed


subsection {* Semantic Non-Interference for Weak Control Dependence *}

lemmas WCDNonInterferenceGraph = 
  lift_PDG_weak_backward_slice[OF WWeakControlDependence.PDG_wcd 
  WhileStrongPostdomination_aux _ HighLowDistinct HighLowUNIV]


lemma WCDNonInterference:
  "NonInterferenceIntra src trg knd
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
       (_Entry_) (_Exit_))
     NewEntry (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
     (lift_Use (Uses prog) (_Entry_) (_Exit_) H L) id
     (PDG.PDG_BS src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)
       (StrongPostdomination.weak_control_dependence src trg
         (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
           (_Entry_) (_Exit_)) NewExit))
     reds (labels_LDCFG_nodes prog)
     NewExit H L (LDCFG_node.Node (_Entry_)) (LDCFG_node.Node (_Exit_)) final"
proof -
  from inner_node_exists obtain n where "CFGExit.inner_node sourcenode targetnode 
    (valid_edge prog) (_Entry_) (_Exit_) n" by blast
  then interpret NonInterferenceIntraGraph src trg knd
     "lift_valid_edge (valid_edge prog) sourcenode targetnode kind
       (_Entry_) (_Exit_)"
     NewEntry "lift_Def (Defs prog) (_Entry_) (_Exit_) H L"
     "lift_Use (Uses prog) (_Entry_) (_Exit_) H L" id
     "PDG.PDG_BS src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)
       (StrongPostdomination.weak_control_dependence src trg
         (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
           (_Entry_) (_Exit_)) NewExit)"
     NewExit H L "LDCFG_node.Node (_Entry_)" "LDCFG_node.Node (_Exit_)"
    by(fastforce intro:WCDNonInterferenceGraph)
  interpret BackwardSlice_wf src trg knd
    "lift_valid_edge (valid_edge prog) sourcenode targetnode kind
      (_Entry_) (_Exit_)"
    NewEntry "lift_Def (Defs prog) (_Entry_) (_Exit_) H L"
    "lift_Use (Uses prog) (_Entry_) (_Exit_) H L" id
    "PDG.PDG_BS src trg
       (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
         (_Entry_) (_Exit_))
       (lift_Def (Defs prog) (_Entry_) (_Exit_) H L)
       (lift_Use (Uses prog) (_Entry_) (_Exit_) H L)
       (StrongPostdomination.weak_control_dependence src trg
         (lift_valid_edge (valid_edge prog) sourcenode targetnode kind
           (_Entry_) (_Exit_)) NewExit)" reds "labels_LDCFG_nodes prog"
  proof(unfold_locales)
    fix n c s c' s'
    assume "labels_LDCFG_nodes prog n c" and "\<langle>c,s\<rangle> \<rightarrow>* \<langle>c',s'\<rangle>"
    thus "\<exists>n' as. CFG.path src trg
     (lift_valid_edge (valid_edge prog) sourcenode targetnode kind (_Entry_) (_Exit_))
      n as n' \<and> transfers (CFG.kinds knd as) s = s' \<and>
      preds (CFG.kinds knd as) s \<and> labels_LDCFG_nodes prog n' c'"
      by(rule lifted_CFG_fund_prop)
  qed
  show ?thesis 
  proof(unfold_locales)
    fix c n
    assume "final c" and "labels_LDCFG_nodes prog n c"
    from `final c` have [simp]:"c = Skip" by(cases c) auto
    from `labels_LDCFG_nodes prog n c` obtain nx where [simp]:"n = Node nx"
      and "labels_nodes prog nx Skip" by(cases n) auto
    from `labels_nodes prog nx Skip` have "prog \<turnstile> nx -\<Up>id\<rightarrow> (_Exit_)"
      by(rule final_edge)
    then obtain a where "valid_edge prog a" and "sourcenode a = nx"
      and "kind a = \<Up>id" and "targetnode a = (_Exit_)"
      by(auto simp:valid_edge_def)
    with `labels_nodes prog nx Skip`
    show "\<exists>a. lift_valid_edge (valid_edge prog) sourcenode targetnode
      kind (_Entry_) (_Exit_) a \<and>
      src a = n \<and> trg a = LDCFG_node.Node (_Exit_) \<and> knd a = \<Up>id"
      by(rule_tac x="(Node nx,\<Up>id,Node (_Exit_))" in exI)
        (auto intro!:lve_edge simp:knd_def valid_edge_def)
  qed
qed

end

end