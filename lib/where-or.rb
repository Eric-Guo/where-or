abort "Congrats for being on Rails 5. Now please remove this patch by getting rid of the `where-or` gem" if ActiveRecord::VERSION::MAJOR > 4
# Tested on Rails Rails 4.2.3
warn "Patching ActiveRecord::Relation#or.  This might blow up" if ActiveRecord.version.to_s < '4.2.3'
# https://github.com/rails/rails/commit/9e42cf019f2417473e7dcbfcb885709fa2709f89.patch
# CHANGELOG.md
# *   Added the `#or` method on ActiveRecord::Relation, allowing use of the OR
#     operator to combine WHERE or HAVING clauses.
#
#     Example:
#
#         Post.where('id = 1').or(Post.where('id = 2'))
#         # => SELECT * FROM posts WHERE (id = 1) OR (id = 2)
#
#     *Sean Griffin*, *Matthew Draper*, *Gael Muller*, *Olivier El Mekki*

ActiveSupport.on_load(:active_record) do

  module ActiveRecord::NullRelation
    def or(other)
      other.spawn
    end
  end

  module ActiveRecord::Querying
    delegate :or, to: :all
  end

  module ActiveRecord::QueryMethods

    CLAUSE_METHODS = [:where, :having]

    CLAUSE_METHODS.each do |name|
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_clause                           # def where_clause
          @values[:#{name}] || new_#{name}_clause    #   @values[:where] || new_where_clause
        end                                          # end
                                                     #
        def #{name}_clause=(value)                   # def where_clause=(value)
          raise ImmutableRelation if @loaded
          check_cached_relation                      #   assert_mutability!
          @values[:#{name}] = value                  #   @values[:where] = value
        end                                          # end
      CODE
    end

    def where_values
      where_clause.predicates
    end

    def where_values=(values)
      self.where_clause = ActiveRecord::Relation::WhereClause.new(values || [], where_clause.binds)
    end

    def having_values
      having_clause.predicates
    end

    def having_values=(values)
      self.having_clause = ActiveRecord::Relation::WhereClause.new(values || [], having_clause.binds)
    end

    def bind_values
      where_clause.binds
    end

    def bind_values=(values)
      self.where_clause = ActiveRecord::Relation::WhereClause.new(where_clause.predicates, values || [])
    end

    # Returns a new relation, which is the logical union of this relation and the one passed as an
    # argument.
    #
    # The two relations must be structurally compatible: they must be scoping the same model, and
    # they must differ only by +where+ (if no +group+ has been defined) or +having+ (if a +group+ is
    # present). Neither relation may have a +limit+, +offset+, or +distinct+ set.
    #
    #    Post.where("id = 1").or(Post.where("id = 2"))
    #    # SELECT `posts`.* FROM `posts`  WHERE (('id = 1' OR 'id = 2'))
    #
    def or(other)
      spawn.or!(other)
    end

    def or!(other) # :nodoc:
      unless structurally_compatible_for_or?(other)
        raise ArgumentError, 'Relation passed to #or must be structurally compatible'
      end

      self.where_clause = self.where_clause.or(other.where_clause)
      self.having_clause = self.having_clause.or(other.having_clause)

      self
    end

    private

    def structurally_compatible_for_or?(other) # :nodoc:
      (ActiveRecord::Relation::SINGLE_VALUE_METHODS - [:from]).all? { |m| send("#{m}_value") == other.send("#{m}_value") } &&
        (ActiveRecord::Relation::MULTI_VALUE_METHODS - [:references, :eager_load, :extending, :where, :having, :bind]).all? { |m| send("#{m}_values") == other.send("#{m}_values") }
      # https://github.com/rails/rails/commit/2c46d6db4feaf4284415f2fb6ceceb1bb535f278
      # https://github.com/rails/rails/commit/39f2c3b3ea6fac371e79c284494e3d4cfdc1e929
      # https://github.com/rails/rails/commit/bdc5141652770fd227455681cde1f9899f55b0b9
      # (ActiveRecord::Relation::CLAUSE_METHODS - [:having, :where]).all? { |m| send("#{m}_clause") != other.send("#{m}_clause") }
    end

    def new_where_clause
      ActiveRecord::Relation::WhereClause.empty
    end
    alias new_having_clause new_where_clause
  end

  class ActiveRecord::Relation::WhereClause
    # https://github.com/rails/rails/commit/d26dd00854c783bcb1249168bb3f4adf9f99be6c
    attr_reader :binds, :predicates

    delegate :any?, :empty?, to: :predicates

    def initialize(predicates, binds)
      @predicates = predicates
      @binds = binds
    end

    def +(other)
      ActiveRecord::Relation::WhereClause.new(
        predicates + other.predicates,
        binds + other.binds,
      )
    end

    # monkey patching around the fact that the rails 4.2 implementation is an array of things, all 'and'd together
    # but the rails 5 implemention that they backported replaces that array with ActiveRecord::Relation::WhereClause that
    # contains AND's and OR's ... on testing, I discover it mostly works except when you attempt to use the preloader,
    # which this hack here fixes.
    def -(other)
      raise "where-or internal error: expect only empty array, not #{other.inspect}" unless other.empty? || (other.size == 1 && other.first.blank?)
      [self]
    end

    def merge(other)
      ActiveRecord::Relation::WhereClause.new(
        predicates_unreferenced_by(other) + other.predicates,
        non_conflicting_binds(other) + other.binds,
      )
    end

    def except(*columns)
      ActiveRecord::Relation::WhereClause.new(
        predicates_except(columns),
        binds_except(columns),
      )
    end

    def or(other)
      if empty?
        other
      elsif other.empty?
        self
      else
        ActiveRecord::Relation::WhereClause.new(
          [ast.or(other.ast)],
          binds + other.binds
        )
      end
    end

    def to_h(table_name = nil)
      equalities = predicates.grep(Arel::Nodes::Equality)
      if table_name
        equalities = equalities.select do |node|
          node.left.relation.name == table_name
        end
      end

      binds = self.binds.map { |attr| [attr.name, attr.value] }.to_h

      equalities.map { |node|
        name = node.left.name
        [name, binds.fetch(name.to_s) {
          case node.right
          when Array then node.right.map(&:val)
          when Arel::Nodes::Casted, Arel::Nodes::Quoted
            node.right.val
          end
        }]
      }.to_h
    end

    def ast
      Arel::Nodes::And.new(predicates_with_wrapped_sql_literals)
    end

    def ==(other)
      other.is_a?(ActiveRecord::Relation::WhereClause) &&
        predicates == other.predicates &&
        binds == other.binds
    end

    def invert
      ActiveRecord::Relation::WhereClause.new(inverted_predicates, binds)
    end

    def self.empty
      new([], [])
    end

    protected

    def referenced_columns
      @referenced_columns ||= begin
                                equality_nodes = predicates.select { |n| equality_node?(n) }
                                Set.new(equality_nodes, &:left)
                              end
    end

    private

    def predicates_unreferenced_by(other)
      predicates.reject do |n|
        equality_node?(n) && other.referenced_columns.include?(n.left)
      end
    end

    def equality_node?(node)
      node.respond_to?(:operator) && node.operator == :==
    end

    def non_conflicting_binds(other)
      conflicts = referenced_columns & other.referenced_columns
      conflicts.map! { |node| node.name.to_s }
      binds.reject { |attr| conflicts.include?(attr.name) }
    end

    def inverted_predicates
      predicates.map { |node| invert_predicate(node) }
    end

    def invert_predicate(node)
      case node
      when NilClass
        raise ArgumentError, 'Invalid argument for .where.not(), got nil.'
      when Arel::Nodes::In
        Arel::Nodes::NotIn.new(node.left, node.right)
      when Arel::Nodes::Equality
        Arel::Nodes::NotEqual.new(node.left, node.right)
      when String
        Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new(node))
      else
        Arel::Nodes::Not.new(node)
      end
    end

    def predicates_except(columns)
      predicates.reject do |node|
        case node
        when Arel::Nodes::Between, Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual, Arel::Nodes::LessThanOrEqual, Arel::Nodes::GreaterThanOrEqual
          subrelation = (node.left.kind_of?(Arel::Attributes::Attribute) ? node.left : node.right)
          columns.include?(subrelation.name.to_s)
        end
      end
    end

    def binds_except(columns)
      binds.reject do |attr|
        columns.include?(attr.name)
      end
    end

    def predicates_with_wrapped_sql_literals
      non_empty_predicates.map do |node|
        if Arel::Nodes::Equality === node
          node
        else
          wrap_sql_literal(node)
        end
      end
    end

    def non_empty_predicates
      predicates - ['']
    end

    def wrap_sql_literal(node)
      if ::String === node
        node = Arel.sql(node)
      end
      Arel::Nodes::Grouping.new(node)
    end

  end

  class Arel::Visitors::Visitor
    def visit_ActiveRecord_Relation_WhereClause o, collector
      if o.binds
        visit_Arel_Nodes_And(o.ast, collector)
      else
        collector << '1=1' # no-op
        collector
      end
    end
  end
end
