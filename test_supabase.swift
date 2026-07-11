import Foundation

let url = URL(string: "https://qhgtsguaahpswuoykoxx.supabase.co/rest/v1/messages?select=*")!
var request = URLRequest(url: url)
request.addValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoZ3RzZ3VhYWhwc3d1b3lrb3h4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3NzkxNDIsImV4cCI6MjA5OTM1NTE0Mn0.00Gxl_u9QCCmOWLRhSZY4Yrg6ZeQK2Q7T3NBh0uKJis", forHTTPHeaderField: "apikey")
request.addValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoZ3RzZ3VhYWhwc3d1b3lrb3h4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3NzkxNDIsImV4cCI6MjA5OTM1NTE0Mn0.00Gxl_u9QCCmOWLRhSZY4Yrg6ZeQK2Q7T3NBh0uKJis", forHTTPHeaderField: "Authorization")

let sem = DispatchSemaphore(value: 0)
let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let data = data, let str = String(data: data, encoding: .utf8) {
        print(str)
    }
    sem.signal()
}
task.resume()
sem.wait()
