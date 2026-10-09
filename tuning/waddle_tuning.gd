class_name WaddleTuning
extends Resource
## The waddles and the families that fill them (see WaddleMatch and WaddleIce, GDD §4.12): eggs,
## chicks, growing up, how much a berg holds and the ice giving way under it. Values live in
## tuning/waddle.tres; mirrored in docs/TUNING.md (Families and waddles).

@export_group("The waddle")
## Penguins standing on the ice within this far of a berg's waddle spot are in its waddle (m).
## Families' penguins count (players and NPCs), the practice dummies don't.
@export var waddle_radius := 7.0

@export_group("Eggs")
## Fill up to at least this much energy out in the water and you're full: an egg is on its way.
## Reach any waddle (yours or anyone's) and you lay it there. Your energy on the way doesn't
## matter, so the overfed drain can't spoil it.
@export var hatch_energy := 85.0
## Laying costs you this much energy (its first meal). The egg hatches after this long (s).
@export var hatch_cost := 10.0
@export var hatch_seconds := 1.4

@export_group("Chicks")
## Stand within this far of a hungry chick (m) and you feed it: a fish's worth of your energy...
@export var feed_radius := 1.8
@export var feed_energy := 10.0
## ...this often (s), but never taking a player below feed_min_energy, or a computer penguin below
## npc_feed_min (they keep more back). Players feed only their own family's chicks; computer
## penguins can't tell and feed any chick that begs (so a chick laid in a rival's waddle is raised
## on their fish: a cuckoo).
@export var feed_interval := 1.6
@export var feed_min_energy := 30.0
@export var npc_feed_min := 30.0
## Feedings it takes to grow a size. It has three sizes: tiny, fluffy, and a big fat fledgling.
@export var feedings_per_size := 2
## What each size weighs, in the waddle's weight (a stuffed adult weighs 1), and how big it looks
## (× an adult penguin).
@export var size_weights := PackedFloat32Array([0.6, 1.4, 2.4])
@export var size_scales := PackedFloat32Array([0.42, 0.58, 0.78])
## A chick wanders this far from where it hatched (m), and waddles over to beg from a penguin within
## beg_range (m) that would feed it and has energy to spare, at this speed (m/s).
@export var wander := 2.5
@export var beg_range := 6.0
@export var walk_speed := 0.9

@export_group("Growing up")
## A fledgling grows up this long after it's full grown (s): it becomes a young adult of its family
## (a computer penguin, and one more life), starting with this much energy.
@export var fledge_seconds := 15.0
@export var fledge_energy := 45.0

@export_group("Families")
## A family stops laying at this many (adults, chicks and eggs together).
@export var family_cap := 12
## A computer penguin with an egg to lay lays it at home while its home waddle would stay under
## this share of what the berg holds even with the chick full grown. Otherwise it takes the egg to
## the rival waddle nearest to breaking within errand_range (m), or an empty berg, and comes home
## (giving up after errand_seconds).
@export var nest_safe := 0.7
@export var errand_range := 140.0
@export var errand_seconds := 70.0

@export_group("Breaking the ice")
## How much weight a berg's waddle holds before the berg breaks up: this much per metre of its reach
## (IceBerg.holds overrides it for one berg). Every penguin in the waddle counts how fat it is (0
## thin to 1 stuffed), and every chick its size's weight.
@export var holds_per_metre := 0.37
## Cracks start to show on the ice once the weight reaches this share of what it holds, and run
## further out as it climbs (they stay when the weight drops: the ice remembers).
@export var crack_from := 0.45
## A berg breaks into this many pieces, each this far above the water and this deep (m). Pieces
## are too small for a waddle.
@export var pieces := 9
@export var piece_freeboard := 0.6
@export var piece_draft := 3.0
## The gag: everyone on it freezes for a beat (s), then the ice bursts. The pieces bob under this
## far (m) and push apart, this far each (m, min to max), over spread_seconds (s).
@export var beat_seconds := 0.8
@export var dip_depth := 1.6
@export var spread := Vector2(3.0, 7.0)
@export var spread_seconds := 7.0
## Everyone on it is thrown up at this speed (m/s), flailing for flail_seconds (s), and comes down
## in the water between the pieces. Its eggs and chicks are lost. A player thrown off watches a wide
## shot for scene_seconds (s) before getting control back.
@export var toss_speed := 6.5
@export var flail_seconds := 1.8
@export var scene_seconds := 4.5
## Every predator heads for the breakup and hunts anyone it can hear, for this long (s).
@export var frenzy_seconds := 40.0
