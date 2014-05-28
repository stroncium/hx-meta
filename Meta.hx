import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
using haxe.macro.Tools;

enum MetaArgs{
  None;
  Any;
  This(args:Array<MetaArg>);
}

enum MetaArgStringType{
  Any;
  FilePath;
  MacroCall;
  TypePath;
}
enum MetaArgType{
  MInt;
  MString;
  MWord;
  MExpr;
  MOpt(t:MetaArgType, ?e:Expr);
  MMore(t:MetaArgType);
}

typedef MetaArg = {
  desc:String,
  type:MetaArgType,
};

// typedef MetaDesc = {
//   name:String,
//   desc:String,
//   use:Int,
//   ?plat:Int,
//   ?args:Array<MetaArg>,
//   ?internal:Bool,
// };

class MetaDesc{
  public var name:String;
  public var desc:String;
  public var usage:Int;
  public var args:Array<MetaArg>;
  public var plat:Int;
  public var internal:Bool;
  public var argsMin:Int;
  public var argsMax:Int;
  public function new(name:String, desc:String, ?usage = Meta.U_CLASS, ?args:Array<MetaArg>, ?plat = Meta.P_ANY, ?internal = false){
    if(args != null && args.length == 0) args = null;
    this.name = name;
    this.desc = desc;
    this.usage = usage;
    this.args = args;
    this.plat = plat;
    this.internal = internal;
    if(args == null){
      argsMin = argsMax = 0;
    }
    else{
      argsMax = args.length;
      var min = 0;
      var metOpt = false;
      for(i in 0...args.length) switch(args[i].type){
        case MOpt(_):
          metOpt = true;
        case MMore(_):
          if(i != args.length - 1) throw 'More(...) can only be last argument';
          argsMax = Meta.ARGS_MAX;
        case _: 
          if(metOpt) throw 'Normal arguments can\'t follow optional arguments';
          min++;
      }
      argsMin = min;
    }
  }

  public inline function canBeUsed(use:Int){
    return usage & use != 0;
  }

  public function toString(){
    var str = 'Meta @$name $desc\n';
    str+= '  Usable on: ${Meta.usagesToString(usage)}\n';
    if(plat != Meta.P_ANY) str+= '  Platforms: ${Meta.platformsToString(plat)}\n';
    if(args != null){
      str+= '  Arguments:\n';
      for(a in args) str+= '    ${a.type}: ${a.desc}\n';
    }
    if(internal) str+= '  Internal\n';
    return str;
  }

  public function checkMeta(m){
    try{
      parseMeta(m);
      return null;
    }
    catch(e:Dynamic){
      return e;
    }
  }

  static function getBaseArg(t, e):Dynamic{
    return switch(t){
      case MString:
        switch(e.expr){
          case EConst(CString(v)): v;
          case _: throw 'Argument should be String';
        }
      case MInt:
        switch(e.expr){
          case EConst(CInt(v)): v;
          case _: throw 'Argument should be Int';
        }
      case MWord:
        switch(e.expr){
          case EConst(CIdent(v)): v;
          case _: throw 'Argument should be Word';
        }
      case MExpr: e;
      case _: throw 'Incorrect atgument type definition';
    }
  }

  public function parseMeta(m:MetadataEntry):Array<Dynamic>{
    if(name != m.name) throw 'Parsing meta with a wrong name';
    var params = m.params;
    if(params.length > argsMax || params.length < argsMin) throw 'Incorrect number of arguments';

    if(args == null) return null;

    var ret:Array<Dynamic> = [];
    var pos = 0;
    for(i in 0...args.length){
      switch(args[i].type){
        case MOpt(st, def):
          var e = (i < params.length) ? params[i] : def;
          if(e == null) ret.push(null);
          else ret.push(getBaseArg(st, e));
        case MMore(st): 
          switch(st){
            case MExpr: ret.push(params.slice(i));
            case _: ret.push([for(i2 in i...params.length) getBaseArg(st, params[i2])]);
          }
        case t: ret.push(getBaseArg(t, params[i]));
      }
    }
    return ret;
  }

}

class Meta{
  public static inline var ARGS_MAX = 20;
  public static inline var P_JAVA   = 0x01;
  public static inline var P_JS     = 0x02;
  public static inline var P_PYTHON = 0x04;
  public static inline var P_CS     = 0x08;
  public static inline var P_CPP    = 0x10;
  public static inline var P_FLASH  = 0x20;
  public static inline var P_FLASH8 = 0x40;
  public static inline var P_PHP    = 0x80;

  public static inline var P_MAX = P_PHP;

  public static inline var P_ANY    = 0xFF;

  public static inline var U_CLASS_MEMBER    = 0x001;
  public static inline var U_CLASS_METHOD    = 0x002;
  public static inline var U_ABSTRACT_MEMBER = 0x004;
  public static inline var U_ABSTRACT_METHOD = 0x008;
  public static inline var U_CLASS           = 0x010;
  public static inline var U_ABSTRACT        = 0x020;
  public static inline var U_ENUM            = 0x040;
  public static inline var U_TYPEDEF         = 0x080;
  public static inline var U_EXPR            = 0x100;

  public static inline var U_MAX            = U_EXPR;

  public static inline var U_CLASS_FIELD     = U_CLASS_MEMBER | U_CLASS_METHOD;
  public static inline var U_ABSTRACT_FIELD  = U_ABSTRACT_MEMBER | U_ABSTRACT_METHOD;
  public static inline var U_ANY_MEMBER      = U_CLASS_MEMBER | U_ABSTRACT_MEMBER;
  public static inline var U_ANY_METHOD      = U_CLASS_METHOD | U_ABSTRACT_METHOD;
  public static inline var U_ANY_FIELD       = U_CLASS_FIELD | U_ABSTRACT_FIELD;

  static var internalMeta = [for(v in [
    ":accessor", ":ast", ":class", ":csNative", ":dynamicObject", ":enum", ":enumConstructorParam",
    ":exhaustive", ":flatEnum", ":haxeGeneric", ":impl", ":javaNative", ":meta", ":maybeUsed",
    ":mergeBlock", ":nativeGeneric", ":ns", ":realPath", ":requiresAssign", ":replaceReflection",
    ":skipCtor", ":skipReflection", ":this", ":toString", ":valueUsed", ":used"
  ]) v => true];


  public static var usageMapString = [
    U_CLASS_MEMBER    => 'CLASS_MEMBER',
    U_CLASS_METHOD    => 'CLASS_METHOD',
    U_ABSTRACT_MEMBER => 'ABSTRACT_MEMBER',
    U_ABSTRACT_METHOD => 'ABSTRACT_METHOD',
    U_CLASS           => 'CLASS',
    U_ABSTRACT        => 'ABSTRACT',
    U_ENUM            => 'ENUM',
    U_TYPEDEF         => 'TYPEDEF',
    U_EXPR            => 'EXPR',
  ];
  public static var stringMapUsage = {
    var map = [for(v in usageMapString.keys()) usageMapString[v] => v];
    map['CLASS_FIELD']    = U_CLASS_FIELD;
    map['ABSTRACT_FIELD'] = U_ABSTRACT_FIELD;
    map['ANY_MEMBER']     = U_ANY_MEMBER;
    map['ANY_METHOD']     = U_ANY_METHOD;
    map['ANY_FIELD']      = U_ANY_FIELD;
    map;
  }

  public static var platformMapString = [
    P_JAVA => 'Java',
    P_JS => 'JS',
    P_PYTHON => 'Python',
    P_CS => 'CS',
    P_CPP => 'Cpp',
    P_FLASH => 'Flash',
    P_FLASH8 => 'FLASH',
    P_PHP => 'PHP',
  ];

  public static var stringMapPlatform = [
    'JAVA' => P_JAVA,
    'JS' => P_JS,
    'PYTHON' => P_PYTHON,
    'CS' => P_CS,
    'CPP' => P_CPP,
    'FLASH' => P_FLASH,
    'FLASH8' => P_FLASH8,
    'PHP' => P_PHP,
    'ANY' => P_ANY,
  ];

  public static function platformsToString(plats:Int){
    if(plats == P_ANY) return 'Any';
    var mask = 0x001;
    var strs = [];
    while(mask <= P_MAX){
      if(mask & plats != 0) strs.push(platformMapString[mask]);
      mask = mask << 1;
    }
    return strs.join(', ');
  }

  public static function usagesToString(uses:Int){
    var mask = 0x001;
    var strs = [];
    while(mask <= U_MAX){
      if(mask & uses != 0) strs.push(usageMapString[mask]);
      mask = mask << 1;
    }
    return strs.join(', ');
  }

  public static macro function check(){
    for(m in DefaultMetas.ARRAY) allowMeta(m);
    allowMeta(allowMetaDesc);
    haxe.macro.Context.onGenerate(onGenerate);
    return null;
  }

  static inline function invalid(m:MetadataEntry){
    Context.error('Invalid '+metaToString(m), m.pos);
  }


  static inline function getString(e:Expr){
    return switch(e.expr){
      case EConst(CString(str)): str;
      case _:  throw 'not a string';
    }
  }

  static function joinOrs(e:Expr){
    var ret = [];
    function parse(e:Expr) switch(e.expr){
      case EBinop(OpOr, e1, e2):
        parse(e1);
        parse(e2);
      case _: ret.push(e);
    }
    parse(e);
    return ret;
  }

  static function parseUsage(e:Expr){
    var ors = joinOrs(e);
    var ret = 0;
    for(e in ors) switch(e.expr){
      case EConst(CIdent(name)) if(stringMapUsage.exists(name)): ret|= stringMapUsage[name];
      case _: throw 'Invalid usage expression';
    }
    return ret;
  }

  static inline function metaArgTypeFromName(name:String){
    return switch(name){
      case 'Int': MInt;
      case 'String': MString;
      case 'Word': MWord;
      case 'Expr': MExpr;
      case _: throw 'unknown meta argument type name';
    }
  }

  static function parseMetaArgType(e:Expr){
    return switch(e.expr){
      case EConst(CIdent(name)): metaArgTypeFromName(name);
      case ECall({expr:EConst(CIdent(group))},[{expr:EConst(CIdent(name))}]):
        switch(group){
          case 'More': MMore(metaArgTypeFromName(name));
          case 'Opt':MOpt(metaArgTypeFromName(name));
          case _: throw 'Invalid meta arg type expression';
        }
      case _: throw 'Invalid meta arg type expression';
    }
  }

  static function parseArgs(e:Expr){
    switch(e.expr){
      case EArrayDecl(els):
        return [for(el in els){
          switch(el.expr){
            case EMeta({name:'desc', params:[{expr:EConst(CString(desc))}]}, expr): {desc:desc, type:parseMetaArgType(expr)};
            case _: {desc:'--', type:parseMetaArgType(el)};
          }
        }];
      case _: throw 'Invalid arguments expression';
    }
  }

  static inline function parsePlats(e:Expr){
    var ors = joinOrs(e);
    var ret = 0;
    for(e in ors) switch(e.expr){
      case EConst(CIdent(name)) if(stringMapPlatform.exists(name)): ret|= stringMapPlatform[name];
      case _: throw 'Invalid platform expression';
    }
    return ret;
  }

  static var defaultMeta:Map<String,MetaDesc> = [for(m in DefaultMetas.ARRAY) m.name => m];
  static var allowedMeta:Map<String, Array<MetaDesc>> = new Map();

  static function allowMeta(desc:MetaDesc){
    if(internalMeta.exists(desc.name)) throw '@${desc.name} is internal meta name and is not allowed.';
    if(allowedMeta.exists(desc.name)){
      allowedMeta[desc.name].push(desc);
    }
    else{
      allowedMeta[desc.name] = [desc];
    }
    // neko.Lib.println('Allowing: $desc');
  }

  static var allowMetaDesc = new MetaDesc(':allowMeta', 'allows new meta', U_CLASS, [
    {desc: 'name', type:MString},
    {desc: 'description', type:MString},
    {desc: 'usage', type:MOpt(MExpr, macro CLASS)},
    {desc: 'arguments', type:MOpt(MExpr, macro [])},
    {desc: 'platforms', type:MOpt(MExpr, macro ANY)},
  ]);

  static function parseAllowMeta(m:MetadataEntry){
    var margs = allowMetaDesc.parseMeta(m);
    var name = margs[0];
    var desc = margs[1];
    // var usage = margs[2] == null ? U_CLASS : parseUsage(margs[2]);
    // var args = margs[3] == null ? null : parseArgs(margs[3]);
    // var plats = margs[4] == null ? P_ANY : parsePlats(margs[4]);
    var usage = parseUsage(margs[2]);
    var args = parseArgs(margs[3]);
    var plats = parsePlats(margs[4]);
    var newMeta = new MetaDesc(name, desc, usage, args, plats);
    allowMeta(newMeta);
    // var params = m.params;
    // var use = U_CLASS;
    // if(params.length < 2 || params.length > 5) invalid(m);
    // var name = getString(params[0]);
    // var desc = getString(params[1]);
    // var use = U_CLASS, args = null, plats = P_ANY;
    // if(params.length >= 3) use = parseUse(params[2]);
    // if(params.length >= 4) args = parseArgs(params[3]);
    // if(params.length == 5) plats = parsePlats(params[4]);

    // allowMeta(new MetaDesc(name, desc, use, args, plats));
  }



  static function onGenerate(ts:Array<Type>){
    try{
    var unhandled = [];
    // trace(
    // for(m in DefaultMetas.ARRAY) neko.Lib.println(m.toString());


    var typemeta = [];

    for(t in ts) switch(t){
      case TInst(t, ps):
        var type = t.get();
        var meta = type.meta.get();
        for(m in meta){
          if(m.name == ':allowMeta') parseAllowMeta(m);
          // else typemeta.push(m);
        } 
      case _: //unhandled.push(t);
    }

    for(t in ts) switch(t){
      case TInst(t, ps):
        var type = t.get();
        var meta = type.meta.get();
        for(m in meta){
          // neko.Lib.println('${m.pos} ${metaToString(m)}');
          var name = m.name, params = m.params;
          var rules = allowedMeta[name];
          // if(rules == null) rules = [defaultMeta[name]];
          if(rules == null) Context.warning('Not allowed meta ${metaToString(m)}', m.pos);
          else{
            for(rule in rules) if(rule.canBeUsed(U_CLASS)){
              var res = rule.checkMeta(m);
              if(res != null) Context.warning('Invalid ${metaToString(m)} - $res\n$rule', m.pos);
              break;
            }
          }
        } 
      case _:
    }
    }catch(e:Dynamic){
      trace('Macro.check() error: $e');
    }

    // for(m in typemeta){
    //   neko.Lib.println('${m.pos} ${metaToString(m)}');
    //   var name = m.name, params = m.params;
    //   var rules = allowedMeta[name];
    //   if(rules == null) rules = [defaultMeta[name]];
    //   if(rules == null) throw Context.warning('Not allowed meta ${metaToString(m)}', m.pos);
    //   for(rule in rules) if(rule.canBeUsed(U_CLASS)){
    //     var res = rule.checkMeta(m);
    //     if(res != null) Context.warning('Invalid ${metaToString(m)} - $res\n$rule', m.pos);
    //     break;
    //   }
    // }

  }

  static function metaToString(m:MetadataEntry){
    return m.params == null || m.params.length == 0 ? '@'+m.name : '@'+m.name+'('+[for(p in m.params) p.toString()].join(', ')+')';
  }
}
