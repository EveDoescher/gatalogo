"""Split existing shelter geometry so residents can be occluded by its facade."""
from quintal_cozy_models import shelter
from quintal_model_authoring import Model


def shelter_layer(kind, level, state, layer):
    source = shelter(kind, level, state)
    floor = .10 if kind == 'barn' else .31
    depth = 1.40 if kind == 'barn' else 1.12 + (level-1)*1.08
    model = Model()
    for name, mesh in source.parts:
        low, high = mesh.positions.min(0), mesh.positions.max(0)
        # Floor, ramp and rear wall sit behind an animal inside the door.
        back = (high[1] <= floor+.061 or high[2] < -depth/2+.15
                or name.startswith('ramp-'))
        if back == (layer == 'back'):
            model.add(name, mesh)
    return model
