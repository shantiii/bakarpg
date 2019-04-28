module RPGChat
  module Models
    class User
      VERSION = 1 # model version. every change should update this
      attr :id # Integer: Uniquely identifies this user
      attr :format_version # Integer: serialization format number
      attr :revision # Integer: Uniquely identifies revision - prevents clobbers
      attr_accessor :login # String: (uniquely) used to refer to this user
      attr_accessor :characters # Set[Character]: The characters that this user has
      attr_accessor :visibility # Atom: :global, :public, or :hidden
      def initialize()
      end
      def initialize(id, version, revision)
        @id = id
        @format_version = format_version
        @revision = revision
        self
      end
      def <=>(rhs)
        eql_through = proc { |v| return v unless v == 0 }
        eql_through(@login <=> rhs.login)
        eql_through(@characters.to_a.sort <=> rhs.characters.to_a.sort)
        eql_through(@visibility <=> rhs.visibility)
        0
      end
    end
  end
end
