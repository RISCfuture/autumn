# A Person's nickname. If someone changes a person's points using this nickname,
# the correct {Person} instance has their points changed.
#
# Associations
# ------------
#
# | `person` | The {Person} this is a nickname for.
#
# Properties
# ----------
#
# | `name` | The nickname. |

class Pseudonym
  include DataMapper::Resource

  property :id, Serial
  property :name, String, required: true, index: true
  property :person_id, Integer, required: true, index: true

  belongs_to :person
end
