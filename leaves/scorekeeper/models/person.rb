# An IRC member who can give or receive points.
#
# Associations
# ------------
#
# | `scores` | The {Score Scores} given to this Person. |
# | `scores_awarded` | The {Score Scores} awarded by this Person to others. |
# | `pseudonyms` | The {Pseudonym Pseudonyms} this Person goes by on IRC. |
#
# Associations
# ------------
#
# | `server` | The address of the IRC server on which this nick was seen. |
# | `name` | The nick this person used. |
# | `authorized` | If `true`, this Person can award scores. |

class Person
  include DataMapper::Resource

  property :id, Serial
  property :server, String, required: true, unique_index: :server_and_name
  property :name, String, required: true, unique_index: :server_and_name
  property :authorized, Boolean, required: true, default: true

  has n, :scores, child_key: [:receiver_id]
  has n, :scores_awarded, model: 'Score', child_key: [:giver_id]
  has n, :pseudonyms
end
