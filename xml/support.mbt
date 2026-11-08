// Tree navigation helpers used by the XPath axes.
//
// The XPath axes are pure functions of the tree, so they are implemented here
// on the document arena instead of inside the evaluator. Every function returns
// node ids; document order is restored by the caller when a node-set is built.

///|
/// Whether a node is an element.
pub fn Document::is_element(self : Document, id : Int32) -> Bool {
  match self.kind(id) {
    Some(Element) => true
    _ => false
  }
}

///|
/// Whether a node is an attribute.
pub fn Document::is_attribute(self : Document, id : Int32) -> Bool {
  match self.kind(id) {
    Some(Attribute) => true
    _ => false
  }
}

///|
/// Whether a node is a text node.
pub fn Document::is_text(self : Document, id : Int32) -> Bool {
  match self.kind(id) {
    Some(Text) => true
    _ => false
  }
}

///|
/// Whether a node is a comment.
pub fn Document::is_comment(self : Document, id : Int32) -> Bool {
  match self.kind(id) {
    Some(Comment) => true
    _ => false
  }
}

///|
/// Whether a node is a processing instruction.
pub fn Document::is_processing_instruction(self : Document, id : Int32) -> Bool {
  match self.kind(id) {
    Some(ProcessingInstruction) => true
    _ => false
  }
}

///|
/// Whether a node is the document node.
pub fn Document::is_document_node(self : Document, id : Int32) -> Bool {
  match self.kind(id) {
    Some(Document) => true
    _ => false
  }
}

///|
/// Position of a node among its parent's children, or among its element's
/// attributes for attribute nodes.
pub fn Document::index_in_parent(self : Document, id : Int32) -> Int32? {
  let parent = match self.parent(id) {
    Some(parent) => parent
    None => return None
  }
  let siblings = match self.kind(id) {
    Some(Attribute) => self.attributes(parent)
    _ => self.children(parent)
  }
  for i in 0..<siblings.length() {
    if siblings[i] == id {
      return Some(i)
    }
  }
  None
}

///|
/// Descendants of a node in document order, excluding the node itself.
pub fn Document::descendants(self : Document, id : Int32) -> Array[Int32] {
  let result : Array[Int32] = []
  self.collect_descendants(id, result)
  result
}

///|
fn Document::collect_descendants(
  self : Document,
  id : Int32,
  result : Array[Int32],
) -> Unit {
  for child in self.children(id) {
    result.push(child)
    self.collect_descendants(child, result)
  }
}

///|
/// Descendants of a node in document order, including the node itself.
pub fn Document::descendants_or_self(
  self : Document,
  id : Int32,
) -> Array[Int32] {
  let result : Array[Int32] = [id]
  self.collect_descendants(id, result)
  result
}

///|
/// Ancestors of a node, nearest first.
pub fn Document::ancestors(self : Document, id : Int32) -> Array[Int32] {
  let result : Array[Int32] = []
  let mut current = self.parent(id)
  while current is Some(ancestor) {
    result.push(ancestor)
    current = self.parent(ancestor)
  }
  result
}

///|
/// Ancestors of a node, nearest first, including the node itself.
pub fn Document::ancestors_or_self(self : Document, id : Int32) -> Array[Int32] {
  let result : Array[Int32] = [id]
  for ancestor in self.ancestors(id) {
    result.push(ancestor)
  }
  result
}

///|
/// Siblings following a node, in document order.
pub fn Document::following_siblings(
  self : Document,
  id : Int32,
) -> Array[Int32] {
  let result : Array[Int32] = []
  let index = match self.index_in_parent(id) {
    Some(index) => index
    None => return result
  }
  let parent = match self.parent(id) {
    Some(parent) => parent
    None => return result
  }
  let siblings = self.children(parent)
  for i in (index + 1)..<siblings.length() {
    result.push(siblings[i])
  }
  result
}

///|
/// Siblings preceding a node, in document order.
pub fn Document::preceding_siblings(
  self : Document,
  id : Int32,
) -> Array[Int32] {
  let result : Array[Int32] = []
  let index = match self.index_in_parent(id) {
    Some(index) => index
    None => return result
  }
  let parent = match self.parent(id) {
    Some(parent) => parent
    None => return result
  }
  let siblings = self.children(parent)
  for i in 0..<index {
    result.push(siblings[i])
  }
  result
}

///|
/// All element, text, comment and processing-instruction nodes of the document
/// in document order. Attribute nodes are excluded, because XPath never places
/// them in the `following` or `preceding` axis.
pub fn Document::nodes_in_document_order(self : Document) -> Array[Int32] {
  let result : Array[Int32] = []
  self.collect_in_order(0, result)
  result
}

///|
fn Document::collect_in_order(
  self : Document,
  id : Int32,
  result : Array[Int32],
) -> Unit {
  result.push(id)
  for child in self.children(id) {
    self.collect_in_order(child, result)
  }
}

///|
/// Nodes following a node in document order, excluding its descendants and all
/// attribute nodes.
pub fn Document::following(self : Document, id : Int32) -> Array[Int32] {
  let order = self.nodes_in_document_order()
  let last_descendant = match self.descendants(id).last() {
    Some(last) => last
    None => id
  }
  let threshold = self.document_order(last_descendant)
  let result : Array[Int32] = []
  for node in order {
    if self.document_order(node) > threshold {
      result.push(node)
    }
  }
  result
}

///|
/// Nodes preceding a node in document order, excluding its ancestors.
pub fn Document::preceding(self : Document, id : Int32) -> Array[Int32] {
  let order = self.nodes_in_document_order()
  let threshold = self.document_order(id)
  let result : Array[Int32] = []
  for node in order {
    if self.document_order(node) < threshold {
      let mut is_ancestor = false
      for ancestor in self.ancestors(id) {
        if ancestor == node {
          is_ancestor = true
        }
      }
      if !is_ancestor {
        result.push(node)
      }
    }
  }
  result
}

///|
/// Root of the tree containing a node, which is the document node for parsed
/// documents.
pub fn Document::root_of(self : Document, id : Int32) -> Int32 {
  let mut current = id
  let mut finished = false
  while !finished {
    match self.parent(current) {
      Some(parent) => current = parent
      None => finished = true
    }
  }
  current
}

///|
/// Sort node ids into document order and drop duplicates.
pub fn Document::sort_document_order(
  self : Document,
  ids : Array[Int32],
) -> Array[Int32] {
  let sorted = ids.copy()
  let document = self
  sorted.sort_by(fn(a, b) { document.compare_order(a, b) })
  let result : Array[Int32] = []
  let mut previous : Int32? = None
  for id in sorted {
    let duplicate = match previous {
      Some(previous_id) => previous_id == id
      None => false
    }
    if !duplicate {
      result.push(id)
      previous = Some(id)
    }
  }
  result
}
