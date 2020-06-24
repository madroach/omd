type attributes =
  (string * string) list

type 'a link_def =
  {
    label: 'a;
    destination: string;
    title: string option;
  }

type block_list_kind =
  | Ordered of int * char
  | Unordered of char

let same_block_list_kind k1 k2 =
  match k1, k2 with
  | Ordered (_, c1), Ordered (_, c2)
  | Unordered c1, Unordered c2 -> c1 = c2
  | _ -> false

type block_list_style =
  | Loose
  | Tight

module type T = sig
  type t
end

module MakeBlock (Inline : T) = struct
  type block_list =
    {
      kind: block_list_kind;
      style: block_list_style;
      blocks: t list list;
    }

  and def_elt =
    {
      term: Inline.t;
      defs: Inline.t list;
    }

  and def_list =
    {
      content: def_elt list
    }

  and t =
    {
      bl_desc: t_desc;
      bl_attributes: attributes;
    }

  and t_desc =
    | Paragraph of Inline.t
    | List of block_list
    | Blockquote of t list
    | Thematic_break
    | Heading of int * Inline.t
    | Code_block of string * string
    | Html_block of string
    | Link_def of string link_def
    | Def_list of def_list

  let defs ast =
    let rec loop acc {bl_desc; bl_attributes} =
      match bl_desc with
      | List l -> List.fold_left (List.fold_left loop) acc l.blocks
      | Blockquote l -> List.fold_left loop acc l
      | Paragraph _ | Thematic_break | Heading _
      | Def_list _ | Code_block _ | Html_block _ -> acc
      | Link_def def -> (def, bl_attributes) :: acc
    in
    List.rev (List.fold_left loop [] ast)
end

module Inline = struct
  type code =
    {
      content: string;
    }

  and t =
    {
      il_desc: t_desc;
      il_attributes: attributes;
    }

  and t_desc =
    | Concat of t list
    | Text of string
    | Emph of t
    | Strong of t
    | Code of code
    | Hard_break
    | Soft_break
    | Link of t link_def
    | Image of t link_def
    | Html of string
end

module Raw = MakeBlock (String)

module Block = MakeBlock (Inline)

module MakeMapper (Src : T) (Dst : T) = struct
  module SrcBlock = MakeBlock(Src)
  module DstBlock = MakeBlock(Dst)

  let rec map (f : Src.t -> Dst.t) : SrcBlock.t -> DstBlock.t =
    fun {bl_desc; bl_attributes} ->
    let bl_desc =
      match bl_desc with
      | SrcBlock.Paragraph x -> DstBlock.Paragraph (f x)
      | List {kind; style; blocks} ->
          List  {kind; style; blocks = List.map (List.map (map f)) blocks}
      | Blockquote xs ->
          Blockquote (List.map (map f) xs)
      | Thematic_break ->
          Thematic_break
      | Heading (level, text) ->
          Heading (level, f text)
      | Def_list {content} ->
          let f {SrcBlock.term; defs} = {DstBlock.term = f term; defs = List.map f defs} in
          Def_list {content = List.map f content}
      | Code_block (label, code) ->
          Code_block (label, code)
      | Html_block x ->
          Html_block x
      | Link_def x ->
          Link_def x
    in
    {bl_desc; bl_attributes}
end

module Mapper = MakeMapper (String) (Inline)
