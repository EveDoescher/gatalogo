"""Source models selected for the Habitat's second decoration set."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class HabitatAsset:
    name: str
    pack: str
    folder: str

    @property
    def model_path(self) -> Path:
        return Path("assets/3d_assets") / self.pack / "Models" / self.folder / f"{self.name}.glb"


DECORATIONS = (
    HabitatAsset("bowl-cereal", "kenney_food-kit", "GLB_format"),
    HabitatAsset("bag", "kenney_food-kit", "GLB_format"),
    HabitatAsset("can-open", "kenney_food-kit", "GLB_format"),
    HabitatAsset("animal-bee", "kenney_cube-pets_1.0", "GLB_format"),
    HabitatAsset("crops_leafsStageA", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("crops_leafsStageB", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("crops_bambooStageA", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("crops_bambooStageB", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("bridge_wood", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("bridge_stoneRound", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("lily_large", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("tree_pineRoundC", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("plant_bushLarge", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("mushroom_tanGroup", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("bowl", "kenney_food-kit", "GLB_format"),
    HabitatAsset("crate", "kenney_pirate-kit", "GLB format"),
    HabitatAsset("platform-planks", "kenney_pirate-kit", "GLB format"),
    HabitatAsset("planter", "kenney_city-kit-suburban_20", "GLB format"),
    HabitatAsset("stump_roundDetailed", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("tent_smallClosed", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("flower_purpleA", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("plant_bushDetailed", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("mushroom_redGroup", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("pot_small", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("tree_palmBend", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("tree_small_fall", "kenney_nature-kit", "GLTF_format"),
    HabitatAsset("building-type-b", "kenney_city-kit-suburban_20", "GLB format"),
    HabitatAsset("building-type-c", "kenney_city-kit-suburban_20", "GLB format"),
)
