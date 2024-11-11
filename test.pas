type
  TokenType = (
    SPACE, 
    NUMB, 
    FUNC, 
    
    PLUS,
    MINUS,
    MUL,
    DIVISION,
    EQUAL,
    
    LPAR,
    RPAR,
    COMMA,
    
    EOE
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
  // английские символы любого регистра или _ 
  // либо после первой буквы могут еще и цифры быть, как в названии переменной
  else if Current() in ['_', 'a'..'z', 'A'..'Z'] then begin
    while Current() in ['0'..'9', '_', 'a'..'z', 'A'..'Z'] do
    begin
      buffer += Current();
      Next();
    end;
    Result := Token.Create(FUNC, buffer);
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
          Result := Token.Create(RPAR, ')'); end;
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
  end;


function Parser.Primary(): IExpression;
var curr: Token;
begin
  curr := Current();
  case curr.tokenT of
    NUMB: Result := NumExpression.Create(curr);
    
  end;
end;


function Parser.Unary(): IExpression;
var 
  curr, last: Token;
  znak: shortint;
begin
  curr := Current();
  last := curr;
  znak := -1;
  if Matching(MINUS, PLUS) then begin
    while true do begin
      curr := Current();
      if Matching(MINUS) then begin
        znak *= -1;
        last = curr;
        continue;
      end;
      if Matching(PLUS) then begin
        last = curr;
        continue;
      end;
      break;
    end;
    Result := znak < 0 ? UnaryExpression.Create(last, Primary()) : Primary();
  end;
  Result := Primary();
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





var s: string;
begin
  while true do
  begin
    Readln(s);
    
    foreach var _token in Tokenizator.Create(s).Tokenize() do
      Write(_token.text, '|');
  end;
end.