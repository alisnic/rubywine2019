require 'parslet'
require "pp"
require "pry"

class Parser < Parslet::Parser
  root :program

  # (puts "Please input your name")
  # (set name (gets))
  # (puts (+ "hello " name))
  rule(:program)    { expression.repeat }
  rule(:expression) { space? >> str('(') >> body >> str(')') >> space? }
  rule(:body)       { (expression | identifier | string).repeat.as(:exp) }
  rule(:identifier) {
    match('[a-z+]').repeat(1).as(:identifier) >> space?
  }
  rule(:space?) { match('\s').repeat(1).maybe }
  rule(:string) {
    str('"') >> (str('"').absent? >> any).repeat.as(:string) >> str('"') >> space?
  }
end

include Parslet
transform = Parslet::Transform.new

transform.rule(string: simple(:value)) { StringNode.new(value) }
StringNode = Struct.new(:value) do
  def eval
    value.to_s
  end
end

transform.rule(identifier: simple(:value)) { IdentifierNode.new(value) }
IdentifierNode = Struct.new(:value) do
  def eval
    VARS[value.to_s]
  end
end

VARS = {}

transform.rule(exp: subtree(:value)) { ExpressionNode.new(value) }
ExpressionNode = Struct.new(:nodes) do
  def eval
    # [#<struct IdentifierNode value="set"@35>,
    #  #<struct IdentifierNode value="name"@39>,
    #  #<struct ExpressionNode nodes=[#<struct IdentifierNode value="gets"@45>]>]

    if nodes.first.value.to_s == "set"
      # VARS["name"] = Kernel.gets
      VARS[nodes[1].value.to_s] = nodes[2].eval
    elsif nodes.first.value.to_s == "+"
      # "hello " + name
      nodes[1].eval + nodes[2].eval
    else
      Kernel.send(nodes.first.value.to_s, *nodes[1..-1].map(&:eval))
    end
  end
end

parser = Parser.new
nodes = parser.parse(%Q{

(puts "Please input your name")
(set name (gets))
(puts (+ "hello " name))
})

transform.apply(nodes).each(&:eval)
