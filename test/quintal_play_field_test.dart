import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/quintal_play_field.dart';
import 'package:catlogue/game/quintal_play_motion.dart';
void main() {
  test('wand follows vertical and diagonal motion', () {
    final motion = QuintalPlayMotion();
    for (var i = 0; i < 30; i++) { motion.advance(.8, .033, targetY: .9); }
    expect(motion.position, greaterThan(.5));
    expect(motion.positionY, greaterThan(.5));
  });
  test('cat changes axis while walking around a blocked cell', () {
    final free = {for (var x=0;x<3;x++) for(var y=0;y<3;y++) if(x!=1 || y!=1) (x,y)};
    final field = QuintalPlayField((0,1),(0,1),0,free,(_,_)=>true);
    field.aim(const Offset(2,1), (x,y)=>Offset(x.toDouble(),y.toDouble()));
    final visited = <(int,int)>{};
    for (var i=0;i<120;i++) { field.advance(.033); visited.add(field.current); }
    expect(field.current,(2,1));
    expect(visited, isNot(contains((1,1))));
    expect(visited.any((c)=>c.$2!=1),isTrue);
  });
}
