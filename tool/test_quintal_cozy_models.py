"""Geometry invariants that renders alone cannot prove (run with unittest)."""
import tempfile
import unittest
from pathlib import Path
import numpy as np
from habitat_model import read_document,load_model
from quintal_cozy_models import bowl,portions,shelter,kitchen,post,trough
from quintal_model_authoring import bevel_box
from quintal_cozy_crops import crop,fruit_mesh,corn_ear
from build_quintal_crafted_models import nest,BUILDING_STATES


def points(model,prefix):
    return np.concatenate([mesh.positions for name,mesh in model.parts if name.startswith(prefix)])


class CozyModelTests(unittest.TestCase):
    def test_corn_has_kernels_around_its_entire_circumference(self):
        kernels=[mesh.positions.mean(axis=0) for name,mesh in corn_ear().parts if name.startswith('kernel')]
        for y in sorted(set(round(p[1],3) for p in kernels)):
            ring=[p for p in kernels if round(p[1],3)==y]
            angles=np.sort(np.mod([np.arctan2(p[0],p[2]) for p in ring],2*np.pi))
            gaps=np.diff(np.r_[angles,angles[0]+2*np.pi])
            self.assertLess(gaps.max(),.40, 'A side of the cob has no kernels')

    def test_nests_fit_without_overlap_at_the_scene_slot_spacing(self):
        for count in range(3):
            model=nest(count)
            geometry=np.concatenate([m.positions for m in model.meshes])
            self.assertLess(np.ptp(geometry[:,0]),.50)
            eggs=[m.positions for name,m in model.parts if name.startswith('egg-')]
            if count:
                egg_points=np.concatenate(eggs)
                self.assertLess(abs(egg_points[:,0]).max(),.20)
                self.assertGreaterEqual(egg_points[:,1].min(),.085)

    def test_all_crops_have_four_distinct_stages_and_fit_their_bed(self):
        for kind in ('corn','wheat','carrot','turnip','pumpkin','melon'):
            with self.subTest(crop=kind):
                stages=[crop(kind,s) for s in range(4)]
                signatures=[]
                for stage,model in enumerate(stages):
                    geometry=np.concatenate([mesh.positions for mesh in model.meshes])
                    self.assertTrue(np.isfinite(geometry).all())
                    self.assertLess(abs(geometry[:,[0,2]]).max(),.65)
                    self.assertGreater(geometry[:,1].min(),-.02)
                    signatures.append((len(geometry),round(geometry[:,1].max(),4)))
                self.assertEqual(len(set(signatures)),4)
                if kind in ('carrot','turnip'):
                    shoulder=points(stages[-1],'root-shoulder')
                    self.assertGreaterEqual(shoulder[:,1].min(),0)
                    self.assertLessEqual(shoulder[:,1].max(),.13)
                if kind in ('pumpkin','melon'):
                    self.assertFalse(any(n.startswith('fruit-skin') for n,_ in stages[1].parts))
                    self.assertTrue(any(n.startswith('fruit-skin') for n,_ in stages[2].parts))

    def test_fruit_normals_face_outward(self):
        for kind in ('pumpkin','melon'):
            model=fruit_mesh(kind,True)
            center=np.array([0,.155 if kind=='pumpkin' else .15,0])
            for name,mesh in model.parts:
                if name.startswith('fruit-skin'):
                    self.assertTrue(np.all(((mesh.positions-center)*mesh.normals).sum(axis=1)>0))

    def test_bowl_has_same_shell_but_readably_different_contents(self):
        for kind in ('food','water','grain'):
            empty,half,full=[bowl(kind,i) for i in range(3)]
            for other in (half,full):
                np.testing.assert_equal(points(empty,'ceramic-bowl'),points(other,'ceramic-bowl'))
            prefix='water-level' if kind=='water' else 'ration-'
            low,high=points(half,prefix),points(full,prefix)
            self.assertGreater(high[:,1].max()-low[:,1].max(),.08)
            self.assertLess(high[:,1].max(),points(full,'ceramic-bowl')[:,1].max())
            self.assertGreater(low[:,1].min(),.073)

    def test_more_portions_never_adds_another_container(self):
        empty,one,many=[portions(n) for n in (0,1,3)]
        for other in (one,many):
            np.testing.assert_equal(points(empty,'serving-dish'),points(other,'serving-dish'))
            self.assertEqual(sum(n=='serving-dish' for n,_ in other.parts),1)
        self.assertGreater(points(many,'ration-')[:,1].max(),points(one,'ration-')[:,1].max()+.06)

    def test_trough_hay_and_water_stay_inside_the_cavity(self):
        for kind in ('hay','water'):
            for amount in (1,2):
                model=trough(kind,amount)
                contents=points(model,'water' if kind=='water' else 'hay-')
                self.assertLess(contents[:,1].max(),.525)
                self.assertGreater(contents[:,1].min(),.28)
                self.assertLess(abs(contents[:,0]).max(),.69)
                self.assertLess(abs(contents[:,2]).max(),.27)

    def test_bevels_have_outward_normals(self):
        mesh=bevel_box((1,1,1))
        self.assertTrue(np.all((mesh.positions*mesh.normals).sum(axis=1)>0))

    def test_editable_glbs_roundtrip_geometry_and_materials(self):
        cases=[bowl('food',2),trough('hay',2),portions(3),post('ready')]
        for level,state in BUILDING_STATES:
            cases += [shelter('coop',level,state),shelter('barn',level,state),kitchen(level,state)]
        with tempfile.TemporaryDirectory() as temp:
            for i,model in enumerate(cases):
                with self.subTest(model=i):
                    names=[n for n,_ in model.parts]
                    self.assertEqual(len(names),len(set(names)))
                    path=Path(temp)/f'{i}.glb';model.export(path)
                    doc,_=read_document(path)
                    self.assertEqual(len(doc['nodes']),len(model.parts))
                    loaded=load_model(path,ground=0)
                    self.assertEqual(len(loaded),len(model.parts))
                    for source,result in zip(model.meshes,loaded):
                        np.testing.assert_allclose(result.positions,source.positions,atol=2e-6)
                        self.assertTrue(np.isfinite(result.normals).all())
                        self.assertGreaterEqual(result.color.min(),0)
                        self.assertLessEqual(result.color.max(),1)


if __name__=='__main__':unittest.main()
