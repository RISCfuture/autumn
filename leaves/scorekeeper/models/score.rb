# A change to a Person's score. It can be positive or negative.
#
# Associations
# ------------
#
# | `giver` | The {Person} who awarded the points. |
# | `receiver` | The {Person} who received the points. |
# | `channel` | The {Channel} in which the transaction took place. |
#
# Properties
# ----------
#
# | `change` | The delta value in points, positive or negative. |
# | `note` | An optional note describing why the points were changed. |

class Score
  include DataMapper::Resource

  property :id, Serial
  property :giver_id, Integer, required: true, index: :giver_and_receiver
  property :receiver_id, Integer, required: true, index: :giver_and_receiver
  property :channel_id, Integer, required: true, index: true
  property :change, Integer, required: true, default: 0
  property :note, String
  timestamps :created_at

  belongs_to :giver, model: 'Person', child_key: [:giver_id]
  belongs_to :receiver, model: 'Person', child_key: [:receiver_id]
  belongs_to :channel

  validates_with_method :cant_give_scores_to_self

  # Returns Scores given to a Person.
  #
  # @param [Person, Array<Person>] people The person or people to list Scores
  #   for.
  # @return [Array<Score>] The Scores that this Person received.

  def self.given_to(people)
    people = [people] unless people.kind_of?(Enumerable)
    people.map! { |person| person.kind_of?(Person) ? person.id : person }
    all(receiver_id: people)
  end

  # Returns Scores awarded by a Person.
  #
  # @param [Person, Array<Person>] people The person or people to list Scores
  #   for.
  # @return [Array<Score>] The Scores that this Person gave.

  def self.given_by(people)
    people = [people] unless people.kind_of?(Enumerable)
    people.map! { |person| person.kind_of?(Person) ? person.id : person }
    all(giver_id: people)
  end

  # Returns Scores given between two dates.
  #
  # @param [Time] start A start date.
  # @param [Time] stop An end date.
  # @return [Array<Score>] The Scores between these times.

  def self.between(start, stop)
    all(created_at: start..stop)
  end

  # @return [Array<Score>] Scores in descending order of newness.

  def self.newest_first
    all(order: [:created_at.desc])
  end

  private

  def cant_give_scores_to_self
    if giver_id == receiver_id then
      [false, "You can't change your own score."]
    else
      true
    end
  end
end
