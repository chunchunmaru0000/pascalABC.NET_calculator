type
  TokenType = (
    SPACE, 
    NUMB, 
    FUNCT, 
    
    PLUS,
    MINUS,
    MUL,
    DIVISION,
    EQUAL,
    
    LPAR,
    RPAR,
    COMMA,
    
    EOE,
    OTHER
  );
  

type
  Token = class
  public
    tokenT: TokenType;
    text: string;
    constructor(t: TokenType; text_: string);
    begin
      tokenT := t;
      text := text_;
    end;
  end;


type
  Tokenizator = class
  private
    position: int64;
  public
    expression: string;
    
    constructor(expression_: string);
    begin
      position := 1;
      expression := expression_;
    end;
    
    
    function Current: char;
    begin
      if position <= expression.Length then
        Result := expression[position]
      else
        Result := '=';
    end;
    
    
    procedure Next();
    begin
      Inc(position);
    end;
    
    function NextToken(): Token;
    function Tokenize(): array of Token;
  end;


function Tokenizator.NextToken(): Token;
var
  type_of_token: TokenType;
  buffer: string;
  text: string;
  start: int64;
begin
  // конец так и так, даже если и = не будет или будет
  if Current() = '=' then
    Result := Token.Create(EOE, '=')
  // скип пробелов
  else if Current() = ' ' then begin
    while Current() = ' ' do
      Next();
    Result := Token.Create(SPACE, '')
  end
  // числа
  else if Current() in ['0'..'9'] then begin
    while Current() in ['0'..'9', '.'] do
    begin
      buffer += Current();
      Next();
    end;
    Result := Token.Create(NUMB, buffer);
  end
  // английские символы любого регистра или _, добавил русские, пусть будут
  // либо после первой буквы могут еще и цифры быть, как в названии переменной
  else if Current() in ['_', 'a'..'z', 'A'..'Z', 'а'..'я', 'А'..'Я', 'ё', 'Ё'] then begin
    while Current() in ['0'..'9', '_', 'a'..'z', 'A'..'Z', 'а'..'я', 'А'..'Я', 'ё', 'Ё'] do
    begin
      buffer += Current();
      Next();
    end;
    Result := Token.Create(FUNCT, buffer);
  end
  else case Current() of
      '+':
        begin
          Next();
          Result := Token.Create(PLUS, '+'); end;
      '-':
        begin
          Next();
          Result := Token.Create(MINUS, '-'); end;
      '*':
        begin
          Next();
          Result := Token.Create(MUL, '*'); end;
      '/':
        begin
          Next();
          Result := Token.Create(DIVISION, '/'); end;
      ',':
        begin
          Next();
          Result := Token.Create(COMMA, ','); end;
      '(':
        begin
          Next();
          Result := Token.Create(LPAR, '('); end;
      ')':
        begin
          Next();
          Result := Token.Create(RPAR, ')'); end
      else begin
        buffer += Current();
        Next();
        Result := Token.Create(OTHER, buffer); end;
      //end;
    end;
end;


function Tokenizator.Tokenize(): array of Token;
var
  tokens: array of Token;
  _token: Token;
  i: int64;
begin
  i := 0;
  SetLength(tokens, i);
  _token := NextToken();
  
  while _token.text <> '=' do
  begin
    if _token.tokenT <> SPACE then begin
      Inc(i);
      SetLength(tokens, i);
      tokens[i - 1] := _token;
    end;
    _token := NextToken();
  end;
  
  SetLength(tokens, i + 1);
  tokens[i] := _token;
  
  Result := tokens;
end;


type
  IExpression = class
  public
    function Evaluated(): real; abstract;
  end;


type
  NumExpression = class(IExpression)
  public
    value: Token;
    
    constructor(_v: Token);
    begin
      value := _v;
    end;
    
    
    function Evaluated(): real; override;
    begin
      Result := StrToFloat(value.text);
    end;
  end;


type
  UnaryExpression = class(IExpression)
  public
    op: Token;
    value: IExpression;
    
    constructor(_op: Token; _v: IExpression);
    begin
      op := _op;
      value := _v;
    end;
    
    
    function Evaluated(): real; override;
    begin
      case op.tokenT of
        PLUS: Result := value.Evaluated();
        MINUS: Result := -value.Evaluated();
      else
        raise(System.Exception.Create('НЕИЗВЕСТНЫЙ УНАРНЫЙ ОПЕРАТОР <' + op.text + '>'));
      end;
    end;
  end;


type
  BinaryExpression = class(IExpression)
  public
    left: IExpression;
    op: Token;
    right: IExpression;
    
    constructor(_left: IExpression; _op: Token; _right: IExpression);
    begin
      left := _left;
      op := _op;
      right := _right;
    end;
    
    
    function Evaluated(): real; override;
    begin
      case op.tokenT of
        PLUS: Result := left.Evaluated() + right.Evaluated();
        MINUS: Result := left.Evaluated() - right.Evaluated();
        MUL: Result := left.Evaluated() * right.Evaluated();
        DIVISION:
          begin
            var r_res: real := right.Evaluated();
            if r_res = 0 then
              raise(System.Exception.Create('ДЕЛЕНИЕ НА 0 ЗНАЧЕНИЯ <' + FloatToStr(left.Evaluated()) + '>'))
            else
              Result := left.Evaluated() / r_res;
          end
      else
        raise(System.Exception.Create('НЕИЗВЕСТНЫЙ БИНАРНЫЙ ОПЕРАТОР <' + op.text + '>'));
      end;
    end;
  end;

// тут описывать все функции
type
  FunctionExpression = class(IExpression)
  public
    func_name: Token;
    parameters: array of IExpression;
    
    constructor(_func_name: Token; _parameters: array of IExpression);
    begin
      func_name := _func_name;
      parameters := _parameters;
    end;
    
    
    function Evaluated(): real; override;
    var 
      pars: array of real;
      i: int64;
    begin
      SetLength(pars, parameters.Length);
      //Writeln(parameters);
      for i := 0 to High(parameters) do
        pars[i] := parameters[i].Evaluated();
      // тут короче вообще все вункции будут просто по названию делать свое дело
      // но можно и вообще сделать реализацию, где добавить абстрактный класс IFunction
      // и на каждую функцию иметь свой отдельный класс, но тут просто в калькуляторе это не требуется
      if pars.Length = 0 then
        Result := 0.0
      else case func_name.text of
        'max': Result := pars.Length = 1 ? pars[0] : Max(pars);
        'min': Result := pars.Length = 1 ? pars[0] : Min(pars);
        
        'sum': Result := pars.Sum();
        'avg': Result := pars.Average();
        
        'sin': Result := Sin(pars[0]);
        'cos': Result := Cos(pars[0]);
        'tg', 'tan': Result := Tan(pars[0]);
        
        // в тз матрицы (NxN),поэтому первым параметром у функции матрицы будет N
        // далее просто как массив но двумерный сам сложится, если парамеров верное число
        'diagonal': begin
          case pars.Length of 
            1: Result := 0.0;
            2: Result := pars[1]; 
            else for i := 1 to pars[0].Trunc() do
              Result := Result + pars[i + pars[0].Trunc() * (i - 1)];
          end;
        end;
          
        else Result := 0.0;
      end;
    end;
  end;

type
  Parser = class
  public
    tokens: array of Token;
    _pos: int64;
    _last: Token;
    
    constructor(t: array of Token);
    begin
      tokens := t;
      _pos := 0;
      _last := tokens[High(tokens)];
    end;
    
    
    function Get(offset: int64): Token;
    var
      pos_off: int64;
    begin
      pos_off := _pos + offset;
      if (pos_off < Length(tokens)) and (pos_off > -1) then
        Result := tokens[pos_off]
      else
        Result := _last;
    end;
    
    
    function Current(): Token;
    begin
      Result := Get(0);
    end;
    
    
    function Consume(_t: TokenType): Token;
    var
      curr: Token;
    begin
      curr := Current();
      if curr.tokenT <> _t then
        raise(System.Exception.Create('ТОКЕН НЕ СОВПАДАЕТ С ОЖИДАЕМЫМ, ТЕКУЩИЙ: ' + Current().text));
      
      Inc(_pos);
      Result := curr;
    end;
    
    
    function Consume(_t0: TokenType; _t1: TokenType): Token;
    var
      curr: Token;
    begin
      curr := Current();
      if (curr.tokenT <> _t0) and (curr.tokenT <> _t1) then
        raise(System.Exception.Create('ТОКЕН НЕ СОВПАДАЕТ С ОЖИДАЕМЫМ, ТЕКУЩИЙ: ' + Current().text));
      
      Inc(_pos);
      Result := curr;
    end;
    
    
    function Matching(_t: TokenType): boolean;
    begin
      if Current().tokenT <> _t then
        Result := false
      else begin
        Inc(_pos);
        Result := true;
      end;
    end;
    
    
    function Matching(_t0: TokenType; _t1: TokenType): boolean;
    begin
      if (Current().tokenT <> _t0) and (Current().tokenT <> _t1) then
        Result := false
      else begin
        Inc(_pos);
        Result := true;
      end;
    end;
    
    
    function Primary(): IExpression;
    function Unary(): IExpression;
    function Muly(): IExpression;
    function Addity(): IExpression;
    function Expression(): IExpression;
  end;


function Parser.Primary(): IExpression;
var 
  curr: Token;
  func_name: Token;
  parameters: array of IExpression;
begin
  curr := Current();
  if Matching(NUMB) then
    Result := NumExpression.Create(curr);
  if Matching(FUNCT) then begin
    func_name := curr;
    Consume(LPAR);
    SetLength(parameters, 1);
    while not Matching(RPAR) do begin
      parameters[High(parameters)] := Expression();
      if Matching(RPAR) then 
        break
      else begin
        Consume(COMMA);
        SetLength(parameters, parameters.Length + 1);
      end;
    end;
    Result := FunctionExpression.Create(func_name, parameters);
  end;
    
end;


function Parser.Unary(): IExpression;
var 
  curr: Token;
begin
  curr := Current();
//  last := curr;
//  znak := -1;
  if Matching(MINUS, PLUS) then 
    Result := UnaryExpression.Create(curr, Primary())
  else
    Result := Primary();
  // здесь может быть можно сделать типа --2 будет возвращать 2 и тд
//    while true do begin
//      curr := Current();
//      if Matching(MINUS) then begin
//        znak *= -1;
//        last := curr;
//        continue;
//      end;
//      if Matching(PLUS) then begin
//        last := curr;
//        continue;
//      end;
//      break;
//    end;
//    Result := znak < 0 ? UnaryExpression.Create(last, Primary()) : Primary();
end;


function Parser.Muly(): IExpression;
var 
  res: IExpression;
  curr: Token;
begin
  res := Unary();
  while true do begin
    curr := Current();
    if Matching(MUL, DIVISION) then begin
      res := BinaryExpression.Create(res, curr, Unary());
      continue;
    end;
    break;
  end;
  Result := res;
end;


function Parser.Addity(): IExpression;
var 
  res: IExpression;
  curr: Token;
begin
  res := Muly();
  while true do begin
    curr := Current();
    if Matching(PLUS, MINUS) then begin
      res := BinaryExpression.Create(res, curr, Muly());
      continue;
    end;
    break;
  end;
  Result := res;
end;


function Parser.Expression(): IExpression;
begin
  Result := Addity();
end;


var s: string;
begin
  while true do
  begin
    Readln(s);
    //Writeln(Tokenizator.Create(s).Tokenize());
    //Writeln(Parser.Create(Tokenizator.Create(s).Tokenize()).Addity());
    Writeln(Parser.Create(Tokenizator.Create(s).Tokenize()).Addity().Evaluated());
  end;
end.