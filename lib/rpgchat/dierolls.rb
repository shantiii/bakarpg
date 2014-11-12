require 'parslet'
require 'securerandom'

module RPGChat
  module DieRolls
    class DieParser < Parslet::Parser
      # Character Classes
      rule(:digitnz) { match['1-9'] }
      rule(:digit) { match['0-9'] }
      rule(:space) { match['\s'] }
      rule(:space?) { space.maybe }
      rule(:operator) { match['-+*'] }
      rule(:sign) { str('+') | str('-') }

      rule(:posint) { str('0') | (digitnz >> digit.repeat(0,100)) }
      rule(:integer) { sign.maybe >> posint }
      rule(:dietype) { match['fFxX'] | posint }
      rule(:dieroll) { posint.maybe.as(:times) >> match['dD'] >> dietype.as(:die) }
      rule(:value) { (dieroll | integer.as(:int)) >> space?}

      rule(:binary_expr) { value.as(:lhs) >> space? >> operator.as(:op) >> space? >> expression.as(:rhs) >> space?}
      rule(:expression) { binary_expr | value }

      root(:expression)
    end

    IntLiteral = Struct.new(:int) do
      def eval
        int.to_i
      end
    end

    DieRoll = Struct.new(:times, :die) do
      def eval
        total = 0
        (times || 1).to_i.times do
          total +=
            if (die == 'f' || die == 'F') #fudge dice are evenly weighted between -1,0,+1
              SecureRandom.random_number(3) - 1
            elsif (die == 'x' || die == 'X') #homebrew system uses this wacky thing
              SecureRandom.random_number(10) - SecureRandom.random_number(10)
            else # numeric die!
              SecureRandom.random_number(die.to_i) + 1
            end
        end
        total
      end
    end

    BinaryExpr = Struct.new(:lhs,:op,:rhs) do
      def eval
        lval = lhs.eval
        rval = rhs.eval
        case op
        when '+' then lval + rval
        when '-' then lval - rval
        when '*' then lval * rval
        end
      end
    end

    class DieTransform < Parslet::Transform
      rule(int: simple(:int)) { IntLiteral.new(int) }
      rule(times: simple(:times),
           die: simple(:die)) { DieRoll.new(times, die) }
      rule(lhs: simple(:lhs),
           rhs: simple(:rhs),
           op: simple(:op)) { BinaryExpr.new(lhs, op, rhs) }
    end

    def self.roll(str = "dX")
      dp = DieParser.new
      dt = DieTransform.new
      dt.apply(dp.parse(str)).eval
    rescue Parslet::ParseFailed => failure
      raise "Syntax Error"
    end
  end
end
