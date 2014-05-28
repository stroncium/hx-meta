// @lol1
// @lol2('lol')
// @lol3('lol', 2, 3)
// @:allowMeta('lol1')
// @:allowMeta('lol2', Dynamic)
@:allowMeta('lol3', 'lolling meta number 3', CLASS | CLASS_FIELD | ABSTRACT_MEMBER)
@:allowMeta(':ahahah', 'desc', CLASS, [
  @desc('int') Int,
  @desc('string') String,
  @desc('any expressions') More(Expr),
], FLASH|JS)


@:ahahah(123, '123', lol, lol1, lol2)
@lol(Main)
class Main{
  public static function main(){
    trace('lol');
    var a = new A();
  }
}

abstract A(Int){
  public function new(){
    this = 1;
  }

  @lol
  @:op(a+b) public inline static function plus(a:A,b:A){
    return new A();
  }
}
