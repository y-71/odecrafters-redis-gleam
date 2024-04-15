import gleam/io

import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet, type Connection}
import gleam/bytes_builder
import gleam/string
import gleam/list
import gleam/bit_array
import gleam/result
import gleam/pair
import gleam/dict


  
pub fn main() {
  io.println("Logs from your program will appear here!")
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(dict.new(), None) }, fn(msg, state, conn) {
      let assert Packet(msg) = msg
      
      let cmd = get_cmd(msg)
      
      state
      |> io.debug()
      
      let server_action = fn(state){
        case cmd {
          "ping" -> fn(){
            case send_msg(conn, "PONG"){
              Ok(_)->Ok(state)
              Error(_)->Error("🚨.. failed to send message")
            }
          }
          "echo" -> fn(){
            let txt = get_echo_txt_from(msg)
            case send_msg(conn, txt){
              Ok(_)->Ok(state)
              Error(_)->Error("🚨.. failed to send message")
            }
          }
          "set" -> fn(){
            // use kv <- result.try(get_key_value_pair_from(msg))
            case send_msg(conn, "OK"){
              Ok(_)->{
                case get_key_value_pair_from(msg){
                  Ok(#(key, value))->{
                    Ok(
                      state
                        |> dict.insert(key, value)
                    )
                  }
                  Error(_)->{
                    Ok(state)
                  }
                }
              }
              Error(_)->Error("🚨.. failed to send message")
            }
          }
          "get" -> fn(){
            case send_msg(conn, "bar"){
              Ok(_)->Ok(state)
              Error(_)->Error("🚨.. failed to send message")
            }
          }
          
          _ -> fn(){
            Error("🚨.. unsupported method")
          }
        }
      }
      let new_state = case server_action(state)(){
        Ok(new_state)-> new_state
        Error(_)->state
      }

      new_state
      |> io.debug()
      
      

      actor.continue(new_state)
      |> io.debug()
    })
    |> glisten.serve(6379)
  
  process.sleep_forever()
}

fn get_cmd(msg: BitArray){
  bit_array.to_string(msg) 
  |> result.unwrap("")
  |> string.split(on: "\r\n")
  |> list.at(2)
  |> result.unwrap("")
  |> string.lowercase()
}

fn get_echo_txt_from(msg: BitArray){
  bit_array.to_string(msg) 
  |> result.unwrap("")
  |> string.split(on: "\r\n")
  |> list.drop(3)
  |> list.sized_chunk(into: 2)
  |> list.map(fn(chunk){
    pair.new(
      chunk |> list.at(0) |> result.unwrap(""), 
      chunk |> list.at(1)|> result.unwrap("")
    )})
  |> list.map(fn(window){pair.second(window)})
  |> string.join(with: " ")
  |> string.trim()
}


fn get_key_value_pair_from(msg: BitArray) -> Result(#(String, String), Nil)
{
  let pair_arr = bit_array.to_string(msg) 
  |> result.unwrap("")
  |> string.split(on: "\r\n")
  |> list.drop(3)
  |> list.sized_chunk(into: 2)
  |> list.map(fn(chunk){
    pair.new(
      chunk |> list.at(0) |> result.unwrap(""), 
      chunk |> list.at(1)|> result.unwrap("")
    )})
  |> list.map(fn(window){pair.second(window)})
  |> list.take(2)

  let first_value = list.first(pair_arr)
    |> result.unwrap("")
  let first_value_is_empty = first_value
    |> string.is_empty()
  
  let last_value = list.last(pair_arr)
    |> result.unwrap("")
  let last_value_is_empty = last_value
    |> string.is_empty()
    
  case !first_value_is_empty && !last_value_is_empty {
    True -> Ok(pair.new(first_value, last_value))
    False -> Error(Nil)
  }
}

fn send_msg(conn: Connection(a), msg: String){
  let rds_msg = "+"<>msg<>"\r\n"
  send_tcp_msg(conn, rds_msg)
}

fn send_tcp_msg(conn: Connection(a), msg: String){
  case glisten.send(conn, bytes_builder.from_string(msg)){
            Ok(_) -> Ok("message sent")
            Error(_) -> Error("Error: failed sending message")
          }
}

// fn to_bulk_string(data: String) -> String{
//   let length = string.length(data)
//   "$" <> int.to_string(length) <> "\r\n" <> data <> "\r\n"
// }

