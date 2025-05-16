# Using python's AST module to defeat Yara
This article will touch on python's AST module and how to use it to obfuscate python code. The Mythic agent [Medusa](https://github.com/MythicAgents/Medusa) will be used as an example of successfull obfuscation from yara rules. 

## Python's AST
Python has a module called *AST* or Abstract-Syntax-Tree, which allows us to inspect and change python code in it's AST representation. 

Here's a quick example of a simple function and a fstring and it's AST representation.



<style>
.code-table {
  width: 100%;
  border-collapse: collapse;
  border: none !important; 
  border-top: none !important;
  border-spacing: 0 16px;
}

.code-table td {
  vertical-align: top;
  width: 50%;
  border: none !important; 
}

.code-block {
  overflow-x: auto;
  font-family: monospace;
  font-size: 14px;
  border: none !important; 
  margin: 0;
}

</style>

<table class="code-table">
  <tr>
    <td>
      <pre class="code-block"><code class="lang-python">def myfunction(s):
    return s + "1"

myworld = "World"
result = myfunction(myworld)
print(f"Hello {result} !")</code></pre>
    </td>
    <td>
      <pre class="code-block"><code class="lang-python">Module(
    body=[
        FunctionDef(
            name='myfunction',
            args=arguments(
                args=[
                    arg(arg='s')]),
            body=[
                Return(
                    value=BinOp(
                        left=Name(id='s', ctx=Load()),
                        op=Add(),
                        right=Constant(value='1')))]),
        Assign(
            targets=[
                Name(id='myworld', ctx=Store())],
            value=Constant(value='World')),
        Assign(
            targets=[
                Name(id='result', ctx=Store())],
            value=Call(
                func=Name(id='myfunction', ctx=Load()),
                args=[
                    Name(id='myworld', ctx=Load())])),
        Expr(
            value=Call(
                func=Name(id='print', ctx=Load()),
                args=[
                    JoinedStr(
                        values=[
                            Constant(value='Hello '),
                            FormattedValue(
                                value=Name(id='result', ctx=Load()),
                                conversion=-1),
                            Constant(value=' !')])]))])</code></pre>
    </td>
  </tr>
</table>



As we can see, the function is defined with `FunctionDef`, the **myworld** and **result** variables with `Assign` and the function call to **myfunction** as an `Expr` with a value of `Call`. 

Moreover, the string literals **World**, **Hello** and **!** are defined with `Constant`. The fstring is represented with `JoinedStr`. 

Python's AST module can be used to modify this AST tree by definining methods with the `visit_` prefix, inside a class that inherits `ast.NodeTransformer`.

The following code shows a class that will be used to `visit_Constant` and `visit_JoinedStr`. We also print the new code with `ast.unparse` which transforms our AST back into python code. 


```python
class StringObfuscator(ast.NodeTransformer):
    def __init__(self):
        pass

    def visit_JoinedStr(self, node):
        print(f"visit_JoinedStr: {node}")
        return self.generic_visit(node)


    def visit_Constant(self, node):
        if isinstance(node.value, str):
            print(f"visit_Constant: {ast.dump(node, indent=4)}")
            return node

base_code_ast = ast.parse(fd)
transformer = StringObfuscator()
base_code_obfuscated = transformer.visit(base_code_ast)
ast.fix_missing_locations(base_code_obfuscated)
new_base_code = ast.unparse(base_code_obfuscated)
print(new_base_code)
```
An important section here is `if isinstance(node.value, str):`, we only want to show constants that are strings. 

Running the code shows how are constants are shown in AST. 
```python
visit_Constant: Constant(value='1')
visit_Constant: Constant(value='World')
visit_JoinedStr: JoinedStr(
    values=[
        Constant(value='Hello '),
        FormattedValue(
            value=Name(id='result', ctx=Load()),
            conversion=-1),
        Constant(value=' !')])
visit_Constant: Constant(value='Hello ')
visit_Constant: Constant(value=' !')
```

The recusive nature of this AST module is shown here, as the `JoinedStr` is called, prints the AST of its node, and then continues the "visit" with `generic_visit` which in turn gets to `visit_Constant` and prints **Hello** and **!** again. 

This simply shows that some nodes are comprised of other nodes. 

With this example out of the way, lets see how we can obfuscate strings. 


## String obfuscation

Our objective here is to replace our string constants with a call to a function. For the purpose of this article, our function will base64 encode the string.

Because our class inherits from `ast.NodeTransformer` we are allowed to modify the node and return that new version to the AST. 

In the `visit_Constant` method, we will first check for internal constants, like `__main__` and return the node without modification. 
Then, we access `node.value`, which contains the full string, and we call our obfuscation function `obf_strings`.  

Since we want replace the AST with a function call that will decode the string, the `func` argument for the new `ast.Call` value is going to be our deobfuscation function (in this case, simple base64 decode), and the `args` value the encoded value of the string. 


```python
def visit_Constant(self, node):
    if isinstance(node.value, str):
        if "__main__" in node.value:
            return node
        encoded = obf_strings(node.value).decode()
        return ast.Call(
            func=ast.Name(id="deobf_strings", ctx=ast.Load()),
            args=[ast.Constant(value=encoded)],
            keywords=[]
        )
    return node
```

The AST of the modified code shows that we successfully changed the node. 


<table class="code-table">
    <thead>
          <th style="border: none !important;"> Old AST</td>
          <th style="border: none !important;"> New AST</th>
    </thead> 
  <tr>
    <td>
      <pre class="code-block"><code class="lang-python">Assign(
        targets=[
            Name(id='myworld', ctx=Store())],
        value=Constant(value='World')),</code></pre>
    </td>
    <td>
      <pre class="code-block"><code class="lang-python">Assign(
        targets=[
            Name(id='myworld', ctx=Store())],
        value=Call(
            func=Name(id='deobf_strings', ctx=Load()),
            args=[
                Constant(value='V29ybGQ')]))</code></pre>
    </td>
  </tr>
</table>

If we try to apply this obfuscation to the fstring we had in our example code, we'll get this error: 
```python
raise ValueError(f"Unexpected node inside JoinedStr, {node!r}")
    ValueError: Unexpected node inside JoinedStr, <ast.Call object at 0x00000238C35BD250>
``` 
Looking at the AST we generated, it looks like `ast.Call` replaced the `ast.Constant` as intended. 
```python
Expr(
    value=Call(
        func=Name(id='print', ctx=Load()),
        args=[
            JoinedStr(
                values=[
                    Call(
                        func=Name(id='deobf_strings', ctx=Load()),
                        args=[
                            Constant(value='SGVsbG8g')]),
                    FormattedValue(
                        value=Name(id='result', ctx=Load()),
                        conversion=-1),
                    Call(
                        func=Name(id='deobf_strings', ctx=Load()),
                        args=[
                            Constant(value='ICE')])])]))])
```

The python source code for the AST module here : https://python.langchain.com/api_reference/_modules/ast.html shows the only allowed types in a fstring are `str` `Constant` and `FormattedValue`, not `Call`. 
```python
def _write_fstring_inner(self, node):
    if isinstance(node, JoinedStr):
        # for both the f-string itself, and format_spec
        for value in node.values:
            self._write_fstring_inner(value)
    elif isinstance(node, Constant) and isinstance(node.value, str):
        [SNIP]
    elif isinstance(node, FormattedValue):
        self.visit_FormattedValue(node)
    else:
        raise ValueError(f"Unexpected node inside JoinedStr, {node!r}")
```
We can easily fix the issue by returning a `ast.FormattedValue` type that can contain a function call. ie `f"return value: {givereturn()}"` is valid python code. 

And this is where the recusive nature of AST comes into play, we'll visit a `JoinedStr`, iterate over each nodes, check if the node is of type `ast.Constant`, visit the node , get the `ast.Call` back from our `visit_Constant` function and wrap a `ast.FormattedValue` around the call before continuing the recusive visit with `generic_visit(node)`.  

```python
def visit_JoinedStr(self, node):
    for idx, value in enumerate(node.values):
        if isinstance(value, ast.Constant) and isinstance(value.value, str):
            call_ast = self.visit(value)
            node.values[idx] = ast.FormattedValue(value=call_ast, conversion=-1)
    return self.generic_visit(node)
```

Running our script will generate this python code:
```python
def myfunction(s):
    return s + deobf_strings(b'MQ')
myworld = deobf_strings(b'V29ybGQ')
result = myfunction(myworld)
print(f"{deobf_strings(b'SGVsbG8g')}{result}{deobf_strings(b'ICE')}")
```
We've now successfully hid our strings behind a function call that will decode them at runtime. 

Note, this works for keys and values in a dict as well:
```python
mydict = {'testing': 'value', 'othertest': 'othervalue'}
print(mydict['testing'])
```
Obfuscated result:
```python
mydict = {deobf_strings(b'dGVzdGluZw'): deobf_strings(b'dmFsdWU'), deobf_strings(b'b3RoZXJ0ZXN0'): deobf_strings(b'b3RoZXJ2YWx1ZQ')}
print(mydict[deobf_strings(b'dGVzdGluZw')])
----------EXEC----------
value
```

You will have to include the deobfuscation function in the new code for the function call to work. 


## Variables and arguments obfuscation

For variable names, we'll have to change our example code a bit during this chapter, as variables have different AST types depending on where they are defined. 

Lets start simple: 
```python
def myfunction(s):
    x = s + "1"
    return x

myworld = "World"
result = myfunction(myworld)
print(f"Hello {result} !")
```
Our variables (top to bottom) are **x**, **myworld** and **result**. 

We can create a variable collector to explore variables from the AST:
```python
class VariablesCollector(ast.NodeVisitor):
    def __init__(self):
        self.variables = set()

    def visit_Name(self, node):
        if isinstance(node.ctx, ast.Store):
            self.variables.add(node.id)
        return node

base_code_ast = ast.parse(example_code)
transformer = VariablesCollector()
transformer.visit(base_code_ast)
print(transformer.variables)
```

Our collector returns the variables we saw in our code:
```python
{'myworld', 'x', 'result'}
```

The reason why we are checking for `isinstance(node.ctx, ast.Store)` is because the AST for our example code looks like this:

```python
Assign(
    targets=[
        Name(id='myworld', ctx=Store())],
    value=Constant(value='World')),
Assign(
    targets=[
        Name(id='result', ctx=Store())],
    value=Call(
        func=Name(id='myfunction', ctx=Load()),
        args=[
            Name(id='myworld', ctx=Load())])),
```
When defining a variable, the `ctx` is `Store()`, when using it, `ctx` is `Load()`. We only want variable definitions when building our list of variables, otherwise we'll get `myfunction` which is not a variable, but a function. 


We are missing function arguments, they are variables too ! Let's add a `visit_arg` method to visit all arguments:
```python
def visit_arg(self, node):
    self.variables.add(node.arg)
    return node
```  
The output shows our **s** variable:
`{'myworld', 'result', 'x', 's'}`



We can already see that variables are parsed by the AST differently depending on the context. We can see this further when using classes:
```python
class testing():
    def __init__(self):
        self.myvalue = 123
    def testing_something(self, arg1):
        something = arg1
        something += "something_else"
        self.myvalue += 999
        return something

def myfunction(s):
    x = s + "1"
    return x

myworld = "World"
result = myfunction(myworld)
print(f"Hello {result} !")

testingclass = testing()
print(testingclass.testing_something("something and "))
```
Running our code again shows us: `{'something', 'result', 'self', 'arg1', 'testingclass', 'myworld', 'x', 's'}`

* `self` is the argument to the `__init__` function
* `arg1` is the argument passed to the `testing_something` function
* `something` is the variable defined in the `testing_something` function
* `testingclass` is `testingclass = testing()`

We're still missing `self.myvalue`. This is because this "variable" is an attribute to the `testing` class. 

Adding a `visit_Attribute` method to our AST collector class, shows the `myvalue` attribute in our variable set:
`{'something', 'myvalue', 'x', 'testing_something', 'testingclass', 'myworld', 'arg1', 's', 'self', 'result'}`

```python
def visit_Attribute(self, node):
    self.variables.add(node.attr)
    return node
```

Now we're starting to have issues with some of the names we are capturing, `self` should not be changed, it's internal to Python. We should exclude it in our `visit_arg` function:
```python
def visit_arg(self, node):
    if 'self' not in node.arg:
        self.variables.add(node.arg)
    return node
```
We should do the same with our `visit_Attribute` method. Additionnally, we also need to verify that the `node.value` is of instance `ast.Name`, otherwise, we'll get errors. 

As an example of such an error. Here's our new example code:
```python
import base64
base64.b64encode("asdf"[::-1].encode()).strip(b"=")
```
The AST looks like:

```python
Attribute(
    value=Call( # <--- Attribute value is ast.Call
        func=Attribute(
            value=Name(id='base64', ctx=Load()),
            attr='b64encode',
            ctx=Load()),
        args=[
            Call(
                func=Attribute(
                    value=Subscript( # <--- Attribute value is ast.Subscript
                        value=Constant(value='asdf'),
                        slice=Slice(
                            step=UnaryOp(
                                op=USub(),
                                operand=Constant(value=1))),
                        ctx=Load()),
                    attr='encode',
                    ctx=Load()))]),
    attr='strip',
    ctx=Load())
```
We have an attribute value of type `Call` and `Subscript`, we only want attributes that are `ast.Name` as we're collecting *everything that looks like a variable*.  

```python
def visit_Attribute(self, node):
    if isinstance(node.value, ast.Name):
        if 'self' in node.value.id:
            self.variables.add(node.attr)
    return node
```

------
I'll give you a second to gather your thoughts.

-----

Now that we have a list of variables that should be obfuscated, let's actually do that.

We'll define a new class :
```python
class VariableRenamer(ast.NodeTransformer):
    def __init__(self, variables):
        self.variables = variables
        self.obf_variables = {}
   
    def obfuscate_variable_name(self, name):
        if name not in self.obf_variables:
            self.obf_variables[name] = obf_strings(name).decode()
        return self.obf_variables[name]
    
    def visit_Name(self, node):
        if node.id in self.variables:
            node.id = self.obfuscate_variable_name(node.id)
        return self.generic_visit(node)
    
    def visit_arg(self, node):
        if node.arg in self.variables:
            node.arg = self.obfuscate_variable_name(node.arg)
        return self.generic_visit(node)
    
    def visit_Attribute(self, node):
        if node.attr in self.variables:
            node.attr = self.obfuscate_variable_name(node.attr)
        return self.generic_visit(node)

base_code_ast = ast.parse(example_code)
transformer = VariablesCollector()
transformer.visit(base_code_ast)
transformer = VariableRenamer(transformer.variables)
base_code_obfuscated = transformer.visit(base_code_ast)
ast.fix_missing_locations(base_code_obfuscated)

new_base_code = ast.unparse(base_code_obfuscated)
print(new_base_code)
print("----------EXEC----------")
exec(new_base_code)
```
There's a few things we need to check, first, for each type of "variable" we want to hide, we'll check if it exists in our list of previously collected variables and obfuscate them. Second, we use a helper function to keep track of which variable we've already obfuscated. 

Adding a print statement inside the `obfuscate_variable_name` function shows that the AST recursion makes it so we visit a lot of the same variables, hence the `obf_variables` dict, preventing us from double or triple encoding variables. I'm not sure this code is the more optimized way this could be implemented. 




Running our new code shows that all "variables" are correctly obfuscated. 
```python
class testing:

    def __init__(self):
        self.bXl2YWx1ZQ = 123

    def testing_something(self, YXJnMQ):
        c29tZXRoaW5n = YXJnMQ
        c29tZXRoaW5n += 'something_else'
        self.bXl2YWx1ZQ += 999
        return c29tZXRoaW5n

def myfunction(cw):
    eA = cw + '1'
    return eA
bXl3b3JsZA = 'World'
cmVzdWx0 = myfunction(bXl3b3JsZA)
print(f'Hello {cmVzdWx0} !')
dGVzdGluZ2NsYXNz = testing()
print(dGVzdGluZ2NsYXNz.testing_something('something and '))
----------EXEC----------
Hello World1 !
something and something_else
```



## Function obfuscation

Let's talk about functions. At this point, we know the drill. The `obfuscate_func_name` is the same as the variable function, for now. 


```python
class FunctionObfuscator(ast.NodeTransformer):
    def __init__(self):
        self.func_names = {}

    def obfuscate_func_name(self, name):
        if name not in self.func_names:
            self.func_names[name] = obf_strings(name).decode()
        return self.func_names[name]

    def visit_FunctionDef(self, node):
        self.generic_visit(node)
        # same as the Constants, we avoid obfuscating internal python functions such as
        # __init__
        # __getitem__
        # etc
        if not node.name.startswith('__'): 
            node.name = self.obfuscate_func_name(node.name)
        return node

    def visit_Call(self, node):
        self.generic_visit(node)
        if isinstance(node.func, ast.Name):
            node.func.id = self.obfuscate_func_name(node.func.id)
        return node
```

We are visiting function definitions with `visit_FunctionDef` and function calls with `visit_Call`. 

Using our example code below:
```python
class testing():
    def __init__(self):
        self.myvalue = 123
    def testing_something(self, arg1):
        something = arg1
        something += "something_else"
        self.myvalue += 999
        return something

def myfunction(s):
    x = s + "1"
    return x

myworld = "World"
result = myfunction(myworld)
print(f"Hello {result} !")
testingclass = testing()
print(testingclass.testing_something("something and "))
```

Results in this python code:
```python
class testing:

    def __init__(self):
        self.myvalue = 123

    def dGVzdGluZ19zb21ldGhpbmc(self, arg1):
        something = arg1
        something += 'something_else'
        self.myvalue += 999
        return something

def bXlmdW5jdGlvbg(s):
    x = s + '1'
    return x
myworld = 'World'
result = bXlmdW5jdGlvbg(myworld)
cHJpbnQ(f'Hello {result} !')
testingclass = dGVzdGluZw()
cHJpbnQ(testingclass.testing_something('something and '))
```

Straight away, we see a lot of problemes, our builtin functions are obfuscated, the initialization of the `testing` class is too, but not the class definition, and the call to the method `testingclass.testing_something` is NOT obfuscated. 

Let's treat each issue individually :

**Builtins**

We need to build a list of builtins and other functions that cannot be obfuscated. 

```python
class FunctionObfuscator(ast.NodeTransformer):
    def __init__(self, dontobfuscate):
        self.func_names = {}
        self.dontobfuscate = set(dir(__builtins__))
```

Functions from other modules will also have to be added to `self.dontobfuscate`. Here's an example of the issue:
```python
from os import system
system("whoami")
# Result
from os import system
c3lzdGVt('whoami')
```
AST to the rescue, we can use a `ast.NodeVisitor` to visit the `ImportFrom` type. That will give us `system` in our example. 

```python
class ImportCollector(ast.NodeVisitor):
    def __init__(self):
        self.dontobfuscate_classes = set()

    def visit_ImportFrom(self, node):
        for fn in node.names: self.dontobfuscate_classes.add(fn.name)
```
We pass `ImportCollector.dontobfuscate_classes` to `FunctionObfuscator`. 
```python
class FunctionObfuscator(ast.NodeTransformer):
    def __init__(self, funcdontobfuscate):
        self.dontobfuscate = set(dir(__builtins__))
        for i in funcdontobfuscate: self.dontobfuscate.add(i)
        self.func_names = {}
```
And finally change our `visit_Call`:
```python
def visit_Call(self, node):
    self.generic_visit(node)
    if isinstance(node.func, ast.Name):
        if node.func.id in self.dontobfuscate:
            return node
        node.func.id = self.obfuscate_func_name(node.func.id)
    return node
```


**Class obfuscation**

Here's the code that causes an issue:
```python
class testing:
    def __init__(self):
        self.myvalue = 123
[SNIP]
testingclass = dGVzdGluZw()
```

We have to add a `visit_ClassDef` to our `FunctionObfuscator` class

```python
    def visit_ClassDef(self, node):
        node.name = self.obfuscate_func_name(node.name)
        return node
```
We don't need to add `self.generic_visit(node)` to this visit, as we already have other `visit_*` methods that will visit the nodes we are interested in. 

Now the class definition is obfuscated as well:
```python
class dGVzdGluZw:
    def __init__(self):
        self.myvalue = 123
[SNIP]
testingclass = dGVzdGluZw()
```


**Method obfuscation**

Finally, for the methods of the `testing` class, we add a `visit_Attribute` method to our class. 

```python
def visit_Attribute(self, node):
    self.generic_visit(node)
    if isinstance(node.ctx, ast.Load) and isinstance(node.value, ast.Name):
        # attr is a function (method), which we already obfuscated in visit_FunctionDef()
        if node.attr in self.func_names:
            node.attr = self.func_names[node.attr]
    return node
```

Since the function definition of the method was already processed in our `visit_FunctionDef()` method, we can simply get the encoded value our of the `func_names` dict. 

Here's the AST dump of the node that we should obfuscate. 
```python
Attribute(
    value=Name(id='testingclass', ctx=Load()),
    attr='testing_something',
    ctx=Load())
```


## The End... Maybe ?

Putting everything together gives us :

**Python code**
```python
fd =  """
class testing():
    def __init__(self):
        self.myvalue = 123
    def testing_something(self, arg1):
        something = arg1
        something += "something_else"
        self.myvalue += 999
        return something

def myfunction(s):
    x = s + "1"
    return x

myworld = "World"
result = myfunction(myworld)
print(f"Hello {result} !")

testingclass = testing()
print(testingclass.testing_something("something and "))
"""
```


**Obfuscation code**
```python
base_code_ast = ast.parse(inspect.getsource(deobf_strings) + '\n' + fd)
transformer = VariablesCollector()
transformer.visit(base_code_ast)
all_variables = transformer.variables

transformer = ImportCollector()
transformer.visit(base_code_ast)
dontobfuscate = transformer.dontobfuscate

transformer = VariableRenamer(all_variables)
base_code_obfuscated = transformer.visit(base_code_ast)
ast.fix_missing_locations(base_code_obfuscated)

transformer = FunctionObfuscator(dontobfuscate)
base_code_obfuscated = transformer.visit(base_code_ast)
ast.fix_missing_locations(base_code_obfuscated)

transformer = StringObfuscator()
base_code_obfuscated = transformer.visit(base_code_ast)
ast.fix_missing_locations(base_code_obfuscated)

new_base_code = ast.unparse(base_code_obfuscated)
print(new_base_code)
print("----------EXEC----------")
exec(new_base_code)
```
Notice the `inspect.getsource(deobf_strings)` which includes the source of the `deobf_strings` function into the code we want to obfuscate. 

**Obfuscated result**

```python

def ZGVvYmZfc3RyaW5ncw(ZW5jb2RlZF92YWx1ZQ: bytes) -> str:
    cGFkZGluZ19uZWVkZWQ = 4 - len(ZW5jb2RlZF92YWx1ZQ) % 4
    if cGFkZGluZ19uZWVkZWQ != 4:
        ZW5jb2RlZF92YWx1ZQ += b'=' * cGFkZGluZ19uZWVkZWQ
    return base64.b64decode(ZW5jb2RlZF92YWx1ZQ).decode()

class dGVzdGluZw:
    def __init__(self):
        self.bXl2YWx1ZQ = 123
    def dGVzdGluZ19zb21ldGhpbmc(self, YXJnMQ):
        c29tZXRoaW5n = YXJnMQ
        c29tZXRoaW5n += ZGVvYmZfc3RyaW5ncw(b'c29tZXRoaW5nX2Vsc2U')
        self.bXl2YWx1ZQ += 999
        return c29tZXRoaW5n

def bXlmdW5jdGlvbg(cw):
    eA = cw + ZGVvYmZfc3RyaW5ncw(b'MQ')
    return eA
bXl3b3JsZA = ZGVvYmZfc3RyaW5ncw(b'V29ybGQ')
cmVzdWx0 = bXlmdW5jdGlvbg(bXl3b3JsZA)
print(f"{ZGVvYmZfc3RyaW5ncw(b'SGVsbG8g')}{cmVzdWx0}{ZGVvYmZfc3RyaW5ncw(b'ICE')}")
dGVzdGluZ2NsYXNz = dGVzdGluZw()
print(dGVzdGluZ2NsYXNz.dGVzdGluZ19zb21ldGhpbmc(ZGVvYmZfc3RyaW5ncw(b'c29tZXRoaW5nIGFuZCA')))
```

And it executes fine:
```python
----------EXEC----------
Hello World1 !
something and something_else
```
    

## No, not the end
Issues start here.
#### Lambdas

What about *lambdas* ? This quick python way of defining a anonymous function like so:
```python
xtime = lambda a: (((a << 1) ^ 0x1B) & 0xFF) if (a & 0x80) else (a << 1)

def mix_single_column(a):
    t = a[0] ^ a[1] ^ a[2] ^ a[3]
    u = a[0]
    a[0] ^= t ^ xtime(a[0] ^ a[1])
    a[1] ^= t ^ xtime(a[1] ^ a[2])
    a[2] ^= t ^ xtime(a[2] ^ a[3])
    a[3] ^= t ^ xtime(a[3] ^ u)
```

Running it through our obfuscator give us this : 
```python
def ZGVvYmZfc3RyaW5ncw(ZW5jb2RlZF92YWx1ZQ: bytes) -> str:
    cGFkZGluZ19uZWVkZWQ = 4 - len(ZW5jb2RlZF92YWx1ZQ) % 4
    if cGFkZGluZ19uZWVkZWQ != 4:
        ZW5jb2RlZF92YWx1ZQ += b'=' * cGFkZGluZ19uZWVkZWQ
    return base64.b64decode(ZW5jb2RlZF92YWx1ZQ).decode()
eHRpbWU = lambda YQ: (YQ << 1 ^ 27) & 255 if YQ & 128 else YQ << 1

def bWl4X3NpbmdsZV9jb2x1bW4(YQ):
    dA = YQ[0] ^ YQ[1] ^ YQ[2] ^ YQ[3]
    dQ = YQ[0]
    YQ[0] ^= dA ^ ZUhScGJXVQ(YQ[0] ^ YQ[1])
    YQ[1] ^= dA ^ ZUhScGJXVQ(YQ[1] ^ YQ[2])
    YQ[2] ^= dA ^ ZUhScGJXVQ(YQ[2] ^ YQ[3])
    YQ[3] ^= dA ^ ZUhScGJXVQ(YQ[3] ^ dQ)
```

The xtime was encoded as a variable, and then obfuscated as a function. The `ZUhScGJXVQ` value is :
```bash
❯ echo -n 'eHRpbWU' | base64
ZUhScGJXVQ==
```

That means that the `visit_FunctionDef` method, or more specifically the `obfuscate_func_name` function saw a function name that wasn't already encoded, and encoded it again. 
Why does that happen ? Probably because my code is terrible. 

This is how our code looks like after variable obfuscation:
```python
eHRpbWU = lambda YQ: (YQ << 1 ^ 27) & 255 if YQ & 128 else YQ << 1

def mix_single_column(YQ):
    dA = YQ[0] ^ YQ[1] ^ YQ[2] ^ YQ[3]
    dQ = YQ[0]
    YQ[0] ^= dA ^ eHRpbWU(YQ[0] ^ YQ[1])
    YQ[1] ^= dA ^ eHRpbWU(YQ[1] ^ YQ[2])
    YQ[2] ^= dA ^ eHRpbWU(YQ[2] ^ YQ[3])
    YQ[3] ^= dA ^ eHRpbWU(YQ[3] ^ dQ)
```
This is how our code looks like after function obfuscation:
```python
eHRpbWU = lambda YQ: (YQ << 1 ^ 27) & 255 if YQ & 128 else YQ << 1

def bWl4X3NpbmdsZV9jb2x1bW4(YQ):
    dA = YQ[0] ^ YQ[1] ^ YQ[2] ^ YQ[3]
    dQ = YQ[0]
    YQ[0] ^= dA ^ ZUhScGJXVQ(YQ[0] ^ YQ[1])
    YQ[1] ^= dA ^ ZUhScGJXVQ(YQ[1] ^ YQ[2])
    YQ[2] ^= dA ^ ZUhScGJXVQ(YQ[2] ^ YQ[3])
    YQ[3] ^= dA ^ ZUhScGJXVQ(YQ[3] ^ dQ)
```

In `obfuscate_func_name`, we need to check if the function we are attempting to encoded was already obfuscated by our variable encoder. This way we cover the issues with `lambda` functions. 
```python
class FunctionObfuscator(ast.NodeTransformer):
    def __init__(self, funcdontobfuscate, obf_variables):
        self.dontobfuscate = set(dir(__builtins__))
        self.obf_variables = obf_variables
        for i in funcdontobfuscate: self.dontobfuscate.add(i)
        self.func_names = {}

    def obfuscate_func_name(self, name):
        if name not in self.func_names:
            self.func_names[name] = obf_strings(name).decode()
        if name in self.obf_variables.values():
            for k, v in self.obf_variables.items():
                if name in v:
                    return self.obf_variables[k]
        return self.func_names[name]
```

#### Assignments

Now with assignement issues. The following is valid python code
```python
from threading import Thread
def myfunc():
    return 1
x = myfunc
x()
threads = Thread(target=myfunc)
```

Obfuscated version is this:
```python
from threading import Thread
def bXlmdW5j():
    return 1
eA = myfunc
eA()
dGhyZWFkcw = Thread(target=myfunc)
```
Since `x = myfunc` is just an assignment, or `ast.Assign` type, we never visited the node to check if the RHS (*Right Hand Side*) of the assignement is a function, and therefore didn't change the `myfunc` value, despite having changed it's function definition. 
```python
Assign(
    targets=[
        Name(id='x', ctx=Store())],
    value=Name(id='myfunc', ctx=Load())),
Expr(
    value=Call(
        func=Name(id='x', ctx=Load()))),
```

The same can be said about the threading example, but the function is in the arguments of the function as shown in the AST :
```python
Assign(
    targets=[
        Name(id='threads', ctx=Store())],
    value=Call(
        func=Name(id='Thread', ctx=Load()),
        keywords=[
            keyword(
                arg='target',
                value=Name(id='myfunc', ctx=Load()))]))])
```

I'm assuming that is not that difficult to use the recurive nature of the AST parsing to check assignements and function arguments and compare them to the list of function definition that were already obfuscated, but there would be a lot of edge cases to cover, from list comprehensions, if statements with function calls, generators and everything thing that is legal to put on the *RHS* of an assigment in Python. I'm just happy with my incomplete version here. 







#### Class Definitions

Another issue I've come across when trying to obfuscate Medusa is class definitions. 

Medusa has multiple commands that are built into the agent. One of them (there are others) is the `ps_full` command. It uses `ctypes` and structures to interop with Windows. 

Here's one of the classes *structures* that this command uses:


```python
class RemotePointer(ctypes._Pointer):
    def __getitem__(self, key):
        size = None
        [SNIP]

_remote_pointer_cache = {}
def RPOINTER(dtype):
    [SNIP]
    ptype = type(name, (RemotePointer,), {'_type_': dtype})
```
This looks like the same issue as the assignement we saw above, a Class is defined with `class`, it gets obfuscated because we have a `ClassDef` visitor method, but the assignement doesn't. 

My solution to this is to only obfuscate the *medusa* class, and not the others. 



#### Medusa command functions

Since medusa commands are just functions, some of the commands have internal functions, like the `socks` command with `m2a` and `a2m`.

Like shown previously, function arguments are not parsed by our obfuscator, so code like this (from the `socks` command) is not obfuscated. 

```python
send_thread = Thread(target=a2m, args=(server_id, sock, ), name="a2m:{}".format(server_id))
recv_thread = Thread(target=m2a, args=(server_id, sock, ), name="m2a:{}".format(server_id))
```

Easiest way around this ? Since Medusa is structured like this: 

```python
class medusa():

    def cmd1():
        #command 1
    def cmd2():
        # another command
```
We can use Mythic's RPC at build time to get all the agent's commands, and only obfuscate them, as we know that they won't be used elsewhere. 