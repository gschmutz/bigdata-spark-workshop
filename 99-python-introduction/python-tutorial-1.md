
# Python Tutorial 1

## Operations and Expressions

#### Plus operation


```python
1 + 2
```

#### Multiply Operation


```python
1 * 3
```




    3



#### Devision Operation


```python
1 / 2
```




    0.5




```python
1.0 / 2.0
```




    0.5



#### Modulo Operation


```python
1 % 2
```




    1



#### Order of operations ( * before +)


```python
2 + 3 * 5 + 5
```




    22




```python
(2 + 3) * (5 + 5)
```




    50



## Variables

#### Declare and accessing a variable (no need to specify any type information)


```python
my_variable = 2
```


```python
my_variable
```




    2



#### Expression with a variable


```python
3 * my_variable
```




    6



-----
## Data Types

### Strings


```python
'stringin single quotes'
```




    'stringin single quotes'




```python
"string in double quotes"
```




    'string in double quotes'




```python
"String with an inline ' quote character"
```




    "String with an inline ' quote character"



#### Using print to output a string to console


```python
print ("a string on output")
```

    a string on output


#### Print a variable


```python
msg = "Hello World!"
print (msg)
```

    Hello World!


#### Use Escape characters (i.e. newline)


```python
msg = "Hello\nWorld!"
print (msg)
```

    Hello
    World!


#### String interpolation


```python
"hello {}, python is {} to use".format("world!","fun")
```




    'hello world!, python is fun to use'



### Boolean


```python
True
```




    True




```python
False
```




    False



#### true will not work!


```python
true
```


    ---------------------------------------------------------------------------

    NameError                                 Traceback (most recent call last)

    <ipython-input-37-724ba28f4a9a> in <module>
    ----> 1 true
    

    NameError: name 'true' is not defined


### Lists

#### Creating a list of integers


```python
[1,2,3,4,5]
```




    [1, 2, 3, 4, 5]



#### Creating a list of strings


```python
["Zurich","Berne","Geneva"]
```




    ['Zurich', 'Berne', 'Geneva']



#### Creating a list with mixed types


```python
[1,2,"Berne"]
```




    [1, 2, 'Berne']



#### Using append to add to the list


```python
mylist = [1,2,3]
mylist.append(4)
mylist
```




    [1, 2, 3, 4]



#### Accessing the list by position (zero-based)


```python
mylist[0]
```




    1



#### Changing an item in the list by position


```python
mylist[0] = 2
mylist
```




    [2, 2, 3, 4]



### Dictionaries

#### Creating a dictionary


```python
mydict = {"key1":100, "key2":150}
```

#### Accessing dictionary


```python
mydict["key1"]
```




    100



#### Check if key is in dictionary


```python
"key1" in mydict
```




    True



### Tuples

#### Creating a Tuple


```python
mytuple = (1,2,3,4)
```

#### Accessing a Tuple item


```python
mytuple[0]
```




    1



#### Cannot change an item, Tuple is immutable


```python
mytuple[0] = 2
```


    ---------------------------------------------------------------------------

    TypeError                                 Traceback (most recent call last)

    <ipython-input-54-5b8155753571> in <module>
    ----> 1 mytuple[0] = 2
    

    TypeError: 'tuple' object does not support item assignment


### Sets

#### Create a set (duplicates are removed)


```python
{1,2,3,4,2,3,4}
```




    {1, 2, 3, 4}



#### Ask for membership


```python
1 in {1,2,3,4,2,3,4}
```




    True



#### Union of two sets


```python
{1,2,3,4,2,3,4}.union({5,6,2})
```




    {1, 2, 3, 4, 5, 6}



----
## Comparision Operators


```python
1 == 1
```




    True




```python
1 < 2
```




    True




```python
1 <= 2
```




    True




```python
1 >= 2
```




    False



#### Equality works on string as well


```python
"a string" == "a string"
```




    True




```python
'a string' != 'another string'
```




    True



#### Logical And Operator


```python
(1 > 2) and (1 < 3)
```




    False



#### Logical Or Operator


```python
(1 > 2) or (1 < 3)
```




    True




```python

```
