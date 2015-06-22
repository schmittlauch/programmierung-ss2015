module AM0.Interpreter where
import Prelude hiding (EQ,LT,GT)
import qualified Data.Array.IArray as Array
import qualified Data.IntMap.Strict as IntMap
import Data.List(intercalate)
import Control.Monad.Trans.Class(lift)
import Control.Monad.Trans.Except(Except, catchE, throwE, runExcept, runExceptT)
import Control.Monad.Trans.Writer(Writer, tell, execWriter)
import Numeric(readDec)
import System.Environment(getArgs)
import System.Exit(ExitCode(..), exitWith)
import AM0.Language
import AM0.Lexer(runLexer)
import AM0.Parser(parse)

type Address = Int
type Value = Int
type Stack = [Value]
type Memory = IntMap.IntMap Value
type Input = [Value]
type Output = [Value]

-- Configuration state of an AM0 machine
data Configuration = Configuration { instructionPointer :: Address
                                   , stack :: Stack
                                   , memory :: Memory
                                   , input :: Input
                                   , output :: Output
                                   } deriving (Eq)

instance Show Configuration where
    show (Configuration ip stack mem inp out)
        = "(" ++ intercalate ", " [show (ip + 1), showSequence stack, showMemory mem, showSequence inp, showSequence $ reverse out] ++ ")"

showMemory :: Memory -> String
showMemory mem = "[" ++ (intercalate ", " $ map showMemoryCell $ IntMap.assocs mem) ++ "]"

showMemoryCell :: (Address, Value) -> String
showMemoryCell (a, v) = show (a + 1) ++ "/" ++ show v


showSequence :: Show a => [a] -> String
showSequence [] = "ε"
showSequence as = intercalate ":" $ map show as

-- Possible runtime errors
data Exception = EmptyStack | EmptyInput

data Result = SuccessResult Configuration | ErrorResult Exception

instance Show Exception where
    show EmptyStack = "AM0.Interpreter.Error: Empty stack"
    show EmptyInput = "AM0.Interpreter.Error: Empty input"

type InterpreterM = Writer [Configuration]


main = getArgs >>= handleArgs
usage = putStrLn "Usage: am0 FILE [input..]" >> exit
exit = exitWith ExitSuccess
die = exitWith (ExitFailure 1)

handleArgs []         = usage
handleArgs ["-h"]     = usage
handleArgs ["--help"] = usage
handleArgs (f:inp)    = runFile f inp


runFile :: FilePath -> [String] -> IO ()
runFile fp inp = do
    s <- readFile fp
    inps <- readInputs inp
    case runLexer s (runExceptT parse) of
        Right (Right is) -> run (fromInstructions is) inps
        Right (Left e)   -> putStrLn $ "Parse error: " ++ show e
        Left  s          -> putStrLn $ "Lex error " ++ s

fromInstructions :: [Instruction] -> Program
fromInstructions is = Array.listArray (0, length is - 1) $ reverse is

readInputs = mapM readInput

readInput :: String -> IO Value
readInput s = case readDec s of
    [(n, "")] -> return n
    _         -> putStrLn ("Illegal input number: " ++ s) >> die

run :: Program -> Input -> IO ()
run prog inp = do
    putStrLn $ intercalate "\n" $ map show $ execWriter $ interpret prog inp

interpret :: Program -> Input -> InterpreterM Result
interpret prog inp = interpretStepwise prog (Configuration 0 [] IntMap.empty inp []);


interpretStepwise :: Program -> Configuration -> InterpreterM Result
interpretStepwise prog conf = do
        tell [conf]
        if ip >= l && ip <= h
            then do
                case runExcept $ execute (prog Array.! ip) conf of
                    Left  exc  -> return $ ErrorResult exc
                    Right next -> interpretStepwise prog next
            else return $ SuccessResult conf
    where
        (l, h) = Array.bounds prog
        ip     = instructionPointer conf


memoryLookup :: Address -> Memory -> Value
memoryLookup = IntMap.findWithDefault 0

memoryUpdate :: Address -> Value -> Memory -> Memory
memoryUpdate = IntMap.insert


execute :: Instruction -> Configuration -> Except Exception Configuration
-- Load/Store instructions
execute (READ  n) (Configuration ip stack mem inp out)
    = case inp of
        []   -> throwE EmptyInput
        i:is -> return $ Configuration (ip + 1) stack (memoryUpdate n i mem) is out
execute (WRITE n) (Configuration ip stack mem inp out)
    = return $ Configuration (ip + 1) stack mem inp (memoryLookup n mem : out)
execute (LIT   n) (Configuration ip stack mem inp out)
    = return $ Configuration (ip + 1) (n : stack) mem inp out
execute (LOAD  n) (Configuration ip stack mem inp out)
    = return $ Configuration (ip + 1) (memoryLookup n mem : stack) mem inp out
execute (STORE n) (Configuration ip stack mem inp out)
    = case stack of
        []   -> throwE EmptyStack
        a:as -> return $ Configuration (ip + 1) as (memoryUpdate n a mem) inp out
-- Arithmetic and logical instructions
execute ADD conf = executeStackOperation (+) conf
execute SUB conf = executeStackOperation (-) conf
execute MUL conf = executeStackOperation (*) conf
execute DIV conf = executeStackOperation div conf
execute MOD conf = executeStackOperation mod conf
execute EQ  conf = executeStackOperation ((fromEnum .) . (==)) conf
execute LE  conf = executeStackOperation ((fromEnum .) . (<=)) conf
execute LT  conf = executeStackOperation ((fromEnum .) . (<))  conf
execute GE  conf = executeStackOperation ((fromEnum .) . (>=)) conf
execute GT  conf = executeStackOperation ((fromEnum .) . (>))  conf
-- Control flow instructions
execute (JMP n) (Configuration ip stack mem inp out)
    = return $ Configuration n stack mem inp out
execute (JMC n) (Configuration ip stack mem inp out)
    = case stack of
        []   -> throwE EmptyStack
        0:as -> return $ Configuration n        as mem inp out
        _:as -> return $ Configuration (ip + 1) as mem inp out

executeStackOperation :: (Value -> Value -> Value) -> Configuration -> Except Exception Configuration
executeStackOperation f (Configuration ip stack mem inp out)
    = case stack of
        []     -> throwE EmptyStack
        _:[]   -> throwE EmptyStack
        a:b:cs -> return $ Configuration (ip + 1) (f b a : cs) mem inp out
