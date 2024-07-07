import {TableToTable} from '/xls/tab2tab.js';

// script.js (ES6 module)
export function apiDemo() {
    console.log('Doing something!');

	document.addEventListener('DOMContentLoaded', (event) => {
		const params = document.location.href.split('/');
		const worksheet = params.pop();
		const workbook = params.pop();
		fetch(`/xls/api/${workbook}/${worksheet}`, {
			method: 'GET',
			headers: {
				'Accept': 'application/json'
			}
		})
		.then(response => {
			if (!response.ok) {
				throw new Error('Network response was not ok');
			}
			return response.json();
		})
		.then(data => {
			console.log(data);
			document.getElementById('json').value = JSON.stringify(data);
      //data.values.unshift(data.keys);
			document.getElementById('table').appendChild(TableToTable(data));
		})
		.catch(error => {
			console.error('There has been a problem with your fetch operation:', error);
		});
	});
}