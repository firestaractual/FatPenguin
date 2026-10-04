class_name OrcaPod
extends PredatorPod
## An orca pod (GDD §5.3). Orcas don't chase in open water: on patrol the pod keeps formation and
## an orca only goes after a penguin that comes right up to it. Instead, the pod traps. On the ice:
## the wave (WaveAttack: washes penguins off an ice edge) and the ram (RamAttack: tips a floe, or
## rocks the berg). In the water: the cut-off (CutOffAttack: keeps a penguin from getting home) and
## the carousel (CarouselAttack: rings it in, slaps and lunges). They chain: wave or ram, then
## cut-off, then carousel. Everything a pod does lives in PredatorPod; which attacks it knows and
## their numbers are in tuning/predators/orca_pod.tres. This class is just the name.
