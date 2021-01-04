import UIKit

class RootViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    let daysDataSource = DaysDataSource()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
    }
}

extension RootViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        daysDataSource.days.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let day = daysDataSource.days[indexPath.row]
        cell.textLabel?.text = day.title
        cell.detailTextLabel?.text = day.detail
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let day = daysDataSource.days[indexPath.row]
        navigationController?.pushViewController(day.controller(), animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
