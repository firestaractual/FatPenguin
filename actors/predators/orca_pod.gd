class_name OrcaPod
extends PredatorPod
## An orca pod (GDD §5.3). Orcas don't chase in open water: on patrol the pod keeps formation and
## an orca only goes after a penguin that comes right up to it. Their attacks are the wave
## (WaveAttack: washes penguins off an ice edge) and the ram (RamAttack: tips a floe, or rocks the
## berg). Everything a pod does lives in PredatorPod; which attacks it knows and their numbers are
## in tuning/predators/orca_pod.tres. This class is just the name.
